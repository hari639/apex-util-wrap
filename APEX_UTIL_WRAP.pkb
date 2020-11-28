CREATE OR REPLACE PACKAGE BODY apex_util_wrap AS
-- Description:
--    Generic functions and procedures which can be used in APEX applications
--    Note: EXCEPTION WHEN OTHERS are not handled in this package. Users are free to add their own exception handling code.
--
-- Modification History:
-- =====================
-- Date        Author                    Remarks
-- =========== ======================    =======================================================
-- 15-MAY-2020 Srihari Ravva             Initial version
-- 04-OCT-2020 Srihari Ravva             Added send_mail procedure,
--                                       removed p_template_static_id parameter for merge_placeholders function
-- 26-OCT-2020 Srihari Ravva             Added download_blob procedure and zip related functions
-- 28-NOV-2020 Srihari Ravva             Added get_item_help, get_ig_col_help functions
--

  -- Name             : get_html_table
  -- Description      : function to return SQL query output as HTML table
  -- Parameters       : p_sql_query - SQL Query to execute
  --                    p_bind_variables - list of bind variables used in SQL query, colon seperated
  --                    p_values - values for bind variables, colon seperated
  --                    p_limit_rows - limit number of rows in output
  -- Returns          : HTML table
  --

    FUNCTION get_html_table(
        p_substitution_string   IN                      VARCHAR2
        ,p_sql_query             IN                      VARCHAR2
        ,p_bind_variables        IN                      VARCHAR2
        ,p_values                IN                      VARCHAR2
        ,p_limit_rows            IN                      NUMBER
        ,p_no_data_found         IN                      VARCHAR2
        ,p_more_data_found       IN                      VARCHAR2
    )RETURN CLOB IS

        l_cursor_id            PLS_INTEGER;
        l_execute_output       PLS_INTEGER;
        l_arr_bind_variables   apex_t_varchar2;
        l_arr_bind_values      apex_t_varchar2;
        l_col_count            PLS_INTEGER;
        l_rec_tab              dbms_sql.desc_tab;
        l_vc2_value            VARCHAR2(4000);
        l_num_value            NUMBER;
        l_date_value           DATE;

        -- templates
        -- no styles are defined in templates
        -- l_table_template       VARCHAR2(100):= '<table class="tab-dynamic-data" id="#TABLE_ID#"><tbody>#TABLE#</tbody></table>';
        l_tr_template          VARCHAR2(50):= '<tr class="#TR_CLASS#">#ROW#</tr>';
        l_th_template          VARCHAR2(50):= '<th id="#TH_ID#">#HEADER#</th>';
        l_td_template          VARCHAR2(50):= '<td>#DATA#</td>';
        l_td_colspan           VARCHAR2(100):= '<td colspan="#COL_COUNT#" align="center">#DATA#</td>';
        l_html_table           CLOB;
        l_temp                 VARCHAR2(32767);
        l_row_count            PLS_INTEGER := 0;
        --l_date_format          VARCHAR2(256);
        l_list_sep             VARCHAR2(1);
        l_no_data_found        VARCHAR2(4000);
        l_more_data_found      VARCHAR2(4000);
    BEGIN
        /* set default values */
        -- take date format from application globalization settings
        -- if application date format is not defined, then this substitution string returns NLS date format of current DB Session
        -- In any case when APP_DATE_FORMAT is NULL, fall back to default date format
        -- l_date_format := COALESCE(v('APP_DATE_TIME_FORMAT'),c_default_date_format);
        l_list_sep := c_default_list_sep;
        l_no_data_found := coalesce(
            p_no_data_found
            ,c_default_no_data_found
        );
        l_more_data_found := coalesce(
            p_more_data_found
            ,c_default_more_data_found
        );
        /* open a cursor */
        l_cursor_id := dbms_sql.open_cursor;
        /* parse input SQL query */
        dbms_sql.parse(
            l_cursor_id
            ,p_sql_query
            ,dbms_sql.native
        );
        /* attach bind variables */
        IF p_bind_variables IS NOT NULL THEN
        -- bind variables can be multiple values seperated by colon
        -- convert them to array and process
            l_arr_bind_variables := apex_string.split(
                p_bind_variables
                ,l_list_sep
            );
            l_arr_bind_values := apex_string.split(
                p_values
                ,l_list_sep
            );
            -- attach bind variables to values
            FOR var_idx IN 1..l_arr_bind_variables.count LOOP
                dbms_sql.bind_variable(
                    l_cursor_id
                    ,l_arr_bind_variables(var_idx)
                    ,l_arr_bind_values(var_idx)
                );
            END LOOP;

        END IF;
        -- describe the query to find out number of columns and column names

        dbms_sql.describe_columns(
            l_cursor_id
            ,l_col_count
            ,l_rec_tab
        );
        /* define columns */
        -- also construct html header row
        FOR col_idx IN 1..l_col_count LOOP
            IF l_rec_tab(col_idx).col_type IN(
                dbms_types.typecode_varchar
                ,dbms_types.typecode_varchar2
            )THEN
            -- VARCHAR2
                dbms_sql.define_column(
                    l_cursor_id
                    ,col_idx
                    ,l_vc2_value
                    ,4000
                );
            ELSIF l_rec_tab(col_idx).col_type = dbms_types.typecode_number THEN
            -- NUMBER
                dbms_sql.define_column(
                    l_cursor_id
                    ,col_idx
                    ,l_num_value
                );
            ELSIF l_rec_tab(col_idx).col_type = dbms_types.typecode_date THEN
            -- DATE
                dbms_sql.define_column(
                    l_cursor_id
                    ,col_idx
                    ,l_date_value
                );
            ELSE
            -- consider as VARCHAR2, limit size to 4000
                dbms_sql.define_column(
                    l_cursor_id
                    ,col_idx
                    ,l_vc2_value
                    ,4000
                );
            END IF;
            -- header row
            -- col_name contains column names from SQL query
            -- if alias are specified in SQL query, then we will get alias in col_name

            l_temp := l_temp
                      || replace(
                replace(
                    l_th_template
                    ,'#HEADER#'
                    ,l_rec_tab(col_idx).col_name
                )
                ,'#TH_ID#'
                ,'col' || TO_CHAR(col_idx)
            );

        END LOOP;
        -- append header row to output

        l_temp := replace(
            replace(
                l_tr_template
                ,'#TR_CLASS#'
                ,'tr-header'
            )
            ,'#ROW#'
            ,l_temp
        );

        l_html_table := to_clob(l_temp);
        /* execute the SQL query */
        l_execute_output := dbms_sql.execute(l_cursor_id);
        /* fetch rows */
        WHILE dbms_sql.fetch_rows(l_cursor_id)> 0 LOOP
        -- reset loop variables
            l_temp := NULL;
            -- for each row, loop through columns and get column values
            FOR col_idx IN 1..l_col_count LOOP
            -- handle different data types
                IF l_rec_tab(col_idx).col_type IN(
                    dbms_types.typecode_varchar
                    ,dbms_types.typecode_varchar2
                )THEN
                -- VARCHAR2
                    dbms_sql.column_value(
                        l_cursor_id
                        ,col_idx
                        ,l_vc2_value
                    );
                ELSIF l_rec_tab(col_idx).col_type = dbms_types.typecode_number THEN
                -- NUMBER
                    dbms_sql.column_value(
                        l_cursor_id
                        ,col_idx
                        ,l_num_value
                    );
                    l_vc2_value := TO_CHAR(l_num_value);
                ELSIF l_rec_tab(col_idx).col_type = dbms_types.typecode_date THEN
                -- DATE
                    dbms_sql.column_value(
                        l_cursor_id
                        ,col_idx
                        ,l_date_value
                    );
                    /*l_vc2_value := TO_CHAR(
                        l_date_value
                        ,l_date_format
                    );*/
                    l_vc2_value := TO_CHAR(l_date_value);
                ELSE
                -- consider as VARCHAR2, limit size to 4000
                    dbms_sql.column_value(
                        l_cursor_id
                        ,col_idx
                        ,l_vc2_value
                    );
                END IF;
                -- prepare data row

                l_temp := l_temp
                          || replace(
                    l_td_template
                    ,'#DATA#'
                    ,l_vc2_value
                );
            END LOOP;
            -- append data row to output

            l_temp := replace(
                replace(
                    l_tr_template
                    ,'#TR_CLASS#'
                    ,CASE
                            WHEN MOD(
                                l_row_count + 1
                                ,2
                            )= 0 THEN
                                'tr-even'
                            ELSE
                                'tr-odd'
                        END
                )
                ,'#ROW#'
                ,l_temp
            );

            l_html_table := l_html_table || to_clob(l_temp);
            l_row_count := l_row_count + 1;

            -- addtional exit condition, if user has specified p_limit_rows rows
            -- initial value of l_row_count is 0
            EXIT WHEN l_row_count = p_limit_rows;
        END LOOP;

        -- query returned no rows, then show no data found message
        -- OR there are still more rows to fetchm then show more data found message

        IF l_row_count = 0 OR(l_row_count = p_limit_rows AND dbms_sql.fetch_rows(l_cursor_id)> 0)THEN
            l_temp := replace(
                replace(
                    l_td_colspan
                    ,'#DATA#'
                    ,CASE
                            WHEN l_row_count = 0 THEN
                                l_no_data_found
                            ELSE
                                l_more_data_found
                        END
                )
                ,'#COL_COUNT#'
                ,l_col_count
            );

            l_temp := replace(
                replace(
                    l_tr_template
                    ,'#TR_CLASS#'
                    ,'tr-note'
                )
                ,'#ROW#'
                ,l_temp
            );

            l_html_table := l_html_table || to_clob(l_temp);
        END IF;

        /* close cursor */

        dbms_sql.close_cursor(l_cursor_id);
        /*
        l_html_table := replace(
            replace(
                TO_CLOB(l_table_template)
                ,'#TABLE_ID#'
                ,lower(p_substitution_string)
            )
            ,'#TABLE#'
            ,l_html_table
        );
        */
        l_html_table := '<table class="tab-dynamic-data" id="'
                        || lower(p_substitution_string)
                        || '"><tbody>'
                        || l_html_table
                        || '</tbody></table>';

        RETURN l_html_table;
    EXCEPTION
        WHEN OTHERS THEN
            -- check if cursor is opened, if yes, close it
            IF dbms_sql.is_open(l_cursor_id)THEN
                dbms_sql.close_cursor(l_cursor_id);
            END IF;
            -- no exception handling here, just re raise it
            RAISE;
    END get_html_table;

  -- Name             : merge_placeholders
  -- Description      : function to merge normal placehodlers and table placehodlers (after generating table html)
  --                    returns one placehodlers value which can be used with APEX_MAIL package
  -- Parameters       : p_placeholders - normal placehodlers of the template
  --                    p_table_placeholders - table placehodlers
  -- Returns          : placehodlers CLOB which can be used with APEX_MAIL package
  --

    FUNCTION merge_placeholders(
        p_placeholders         IN                     CLOB
        ,p_table_placeholders   IN                     CLOB
    )RETURN CLOB IS

        l_placeholders          CLOB;
        l_json                  apex_json.t_values;
        l_tables_json           apex_json.t_values;
        l_html_table            CLOB;
        l_arr_names             apex_t_varchar2;
        l_value                 CLOB;
        l_substitution_string   VARCHAR2(4000);
        l_sql_query             VARCHAR2(4000);
        l_bind_var_names        VARCHAR2(4000);
        l_bind_var_values       VARCHAR2(4000);
        l_limit_rows            NUMBER;
        l_no_data_found         VARCHAR2(4000);
        l_more_data_found       VARCHAR2(4000);
    BEGIN
        IF p_table_placeholders IS NOT NULL THEN
        -- table queries are defined
            apex_json.initialize_clob_output;
            apex_json.open_object;
            IF p_placeholders IS NOT NULL THEN
                -- first write all substitution strings defined in p_placeholders
                apex_json.parse(
                    p_values   => l_json
                    ,p_source   => p_placeholders
                );
                l_arr_names := apex_json.get_members(
                    p_path     => '.'
                    ,p_values   => l_json
                );
                FOR idx IN 1..l_arr_names.count LOOP
                    l_value := apex_json.get_clob(
                        p_path     => l_arr_names(idx)
                        ,p_values   => l_json
                    );

                    apex_json.write(
                        l_arr_names(idx)
                        ,l_value
                    );
                END LOOP;

            END IF;
           -- parse table placehodlers JSON

            apex_json.parse(
                p_values   => l_tables_json
                ,p_source   => p_table_placeholders
            );
      /*
      -- Sample JSON Fomrat
      {
        "tables": [
          {
            "substitution_string": "EMP_DATA_TABLE",
            "sql_query": "SELECT * FROM EMP WHERE JOB = :JOB OR ENAME = :ENAME",
            "bind_var_names": "JOB:ENAME",
            "bind_var_values": "MANAGER:KING",
            "limit_rows": "",
            "no_data_found": "No employees exists",
            "more_data_found": "There are more employees exists, however only 5 employees are displayed here. Please login to application to see all employees."
          }
          ,{
            "substitution_string": "DEPT_DATA_TABLE",
            "sql_query": "SELECT DEPTNO "Dept#", DNAME "Dept Name", LOC "Location" FROM DEPT",
            "bind_var_names": "",
            "bind_var_values": "",
            "limit_rows": "",
            "no_data_found": "No deparments exists",
            "more_data_found": ""
          }
        ]
      }
      */
            -- loop for all table queries defined
            FOR tab_idx IN 1..apex_json.get_count(
                p_path     => 'tables'
                ,p_values   => l_tables_json
            )LOOP
                l_substitution_string := apex_json.get_varchar2(
                    p_path     => 'tables[%d].substitution_string'
                    ,p0         => tab_idx
                    ,p_values   => l_tables_json
                );

                l_sql_query := apex_json.get_varchar2(
                    p_path     => 'tables[%d].sql_query'
                    ,p0         => tab_idx
                    ,p_values   => l_tables_json
                );

                l_bind_var_names := apex_json.get_varchar2(
                    p_path     => 'tables[%d].bind_var_names'
                    ,p0         => tab_idx
                    ,p_values   => l_tables_json
                );

                l_bind_var_values := apex_json.get_varchar2(
                    p_path     => 'tables[%d].bind_var_values'
                    ,p0         => tab_idx
                    ,p_values   => l_tables_json
                );

                l_limit_rows := apex_json.get_number(
                    p_path     => 'tables[%d].limit_rows'
                    ,p0         => tab_idx
                    ,p_values   => l_tables_json
                );

                l_no_data_found := apex_json.get_varchar2(
                    p_path     => 'tables[%d].no_data_found'
                    ,p0         => tab_idx
                    ,p_values   => l_tables_json
                );

                l_more_data_found := apex_json.get_varchar2(
                    p_path     => 'tables[%d].more_data_found'
                    ,p0         => tab_idx
                    ,p_values   => l_tables_json
                );

                l_html_table := get_html_table(
                    p_substitution_string   => l_substitution_string
                    ,p_sql_query             => l_sql_query
                    ,p_bind_variables        => l_bind_var_names
                    ,p_values                => l_bind_var_values
                    ,p_limit_rows            => l_limit_rows
                    ,p_no_data_found         => l_no_data_found
                    ,p_more_data_found       => l_more_data_found
                );

                apex_json.write(
                    l_substitution_string
                    ,l_html_table
                );
            END LOOP;

            apex_json.close_object;
            l_placeholders := apex_json.get_clob_output;
            apex_json.free_output;
        ELSE
            -- no tables defined in the template
            l_placeholders := p_placeholders;
        END IF;

        RETURN l_placeholders;
    END merge_placeholders;

  -- Name             : send_mail
  -- Description      : function to send email, calls APEX_MAIL.SEND function
  -- Parameters       : all parameters same as APEX_MAIL.SEND function, one addtional parameter p_table_placeholders
  --                     p_table_placeholders is JSON object passed as CLOB
  --                     {
  --                       "tables": [
  --                         {
  --                           "substitution_string": "EMP_DATA_TABLE",
  --                           "sql_query": "SELECT * FROM EMP WHERE JOB = :JOB OR ENAME = :ENAME",
  --                           "bind_var_names": "JOB:ENAME",
  --                           "bind_var_values": "MANAGER:KING",
  --                           "limit_rows": "5",
  --                           "no_data_found": "No employees exists",
  --                           "more_data_found": "There are more employees exists, however only 5 employees are displayed here. Please login to application to see all employees."
  --                         }
  --                       ]
  --                     }
  --
  -- Returns          : mail id, using which attachments can be added using APEX_MAIL.ADD_ATTACHMENT
  --

    FUNCTION send_mail(
        p_template_static_id   IN                     VARCHAR2
        ,p_placeholders         IN                     CLOB
        ,p_table_placeholders   IN                     CLOB
        ,p_to                   IN                     VARCHAR2
        ,p_cc                   IN                     VARCHAR2 DEFAULT NULL
        ,p_bcc                  IN                     VARCHAR2 DEFAULT NULL
        ,p_from                 IN                     VARCHAR2 DEFAULT NULL
        ,p_replyto              IN                     VARCHAR2 DEFAULT NULL
        ,p_application_id       IN                     NUMBER DEFAULT apex_application.g_flow_id
    )RETURN NUMBER IS
        l_mail_id        NUMBER;
        l_placeholders   CLOB;
    BEGIN
        -- merge normal and table placehodlers
        -- before merging, table placehodlers will be convereted into normal placehodlers, with HTML table data
        l_placeholders := merge_placeholders(
            p_placeholders         => p_placeholders
            ,p_table_placeholders   => p_table_placeholders
        );

        -- Send email using APEX_MAIL.SEND
        l_mail_id := apex_mail.send(
            p_template_static_id   => p_template_static_id
            ,p_placeholders         => l_placeholders
            ,p_to                   => p_to
            ,p_cc                   => p_cc
            ,p_bcc                  => p_bcc
            ,p_from                 => p_from
            ,p_replyto              => p_replyto
            ,p_application_id       => p_application_id
        );

        RETURN l_mail_id;
    END send_mail;

  -- Name             : send_mail
  -- Description      : procedure to send email, calls APEX_UTIL_WRAP.SEND_MAIL function internally
  -- Parameters       : all parameters same as APEX_MAIL.SEND procedure, one addtional parameter p_table_placeholders
  --                     p_table_placeholders is JSON object passed as CLOB
  --                     {
  --                       "tables": [
  --                         {
  --                           "substitution_string": "EMP_DATA_TABLE",
  --                           "sql_query": "SELECT * FROM EMP WHERE JOB = :JOB OR ENAME = :ENAME",
  --                           "bind_var_names": "JOB:ENAME",
  --                           "bind_var_values": "MANAGER:KING",
  --                           "limit_rows": "5",
  --                           "no_data_found": "No employees exists",
  --                           "more_data_found": "There are more employees exists, however only 5 employees are displayed here. Please login to application to see all employees."
  --                         }
  --                       ]
  --                     }
  --
  -- Returns          : n/a
  --

    PROCEDURE send_mail(
        p_template_static_id   IN                     VARCHAR2
        ,p_placeholders         IN                     CLOB
        ,p_table_placeholders   IN                     CLOB
        ,p_to                   IN                     VARCHAR2
        ,p_cc                   IN                     VARCHAR2 DEFAULT NULL
        ,p_bcc                  IN                     VARCHAR2 DEFAULT NULL
        ,p_from                 IN                     VARCHAR2 DEFAULT NULL
        ,p_replyto              IN                     VARCHAR2 DEFAULT NULL
        ,p_application_id       IN                     NUMBER DEFAULT apex_application.g_flow_id
    )IS
        l_mail_id   NUMBER;
    BEGIN
        l_mail_id := send_mail(
            p_template_static_id   => p_template_static_id
            ,p_placeholders         => p_placeholders
            ,p_table_placeholders   => p_table_placeholders
            ,p_to                   => p_to
            ,p_cc                   => p_cc
            ,p_bcc                  => p_bcc
            ,p_from                 => p_from
            ,p_replyto              => p_replyto
            ,p_application_id       => p_application_id
        );
    END send_mail;

  -- Name             : preview_template
  -- Description      : procedure to preview email template output, it is based on APEX_MAIL.PREPARE_TEMPLATE
  -- Parameters       : all parameters similar to APEX_MAIL.PREPARE_TEMPLATE function, with one addtional parameter p_table_placeholders
  --                     p_table_placeholders is JSON object passed as CLOB
  --                     {
  --                       "tables": [
  --                         {
  --                           "substitution_string": "EMP_DATA_TABLE",
  --                           "sql_query": "SELECT * FROM EMP WHERE JOB = :JOB OR ENAME = :ENAME",
  --                           "bind_var_names": "JOB:ENAME",
  --                           "bind_var_values": "MANAGER:KING",
  --                           "limit_rows": "5",
  --                           "no_data_found": "No employees exists",
  --                           "more_data_found": "There are more employees exists, however only 5 employees are displayed here. Please login to application to see all employees."
  --                         }
  --                       ]
  --                     }
  --
  -- Returns          : p_subject, p_html and p_text as OUT parameters, same as APEX_MAIL.PREPARE_TEMPLATE
  --

    PROCEDURE preview_template(
        p_template_static_id   IN                     VARCHAR2
        ,p_placeholders         IN                     CLOB
        ,p_table_placeholders   IN                     CLOB
        ,p_application_id       IN                     NUMBER DEFAULT apex_application.g_flow_id
        ,p_subject              OUT                    VARCHAR2
        ,p_html                 OUT                    CLOB
        ,p_text                 OUT                    CLOB
    )IS
        l_placeholders   CLOB;
    BEGIN
        -- merge normal and table placehodlers
        -- before merging, table placehodlers will be convereted into normal placehodlers, with HTML table data
        l_placeholders := merge_placeholders(
            p_placeholders         => p_placeholders
            ,p_table_placeholders   => p_table_placeholders
        );

        -- call APEX_MAIL.PREPARE_TEMPLATE
        apex_mail.prepare_template(
            p_static_id        => p_template_static_id
            ,p_placeholders     => l_placeholders
            ,p_application_id   => p_application_id
            ,p_subject          => p_subject
            ,p_html             => p_html
            ,p_text             => p_text
        );

    END preview_template;

  -- Name             : download_blob
  -- Description      : procedure to download given BLOB file from browser. Uses SYS.WPG_DOCLOAD.DOWNLOAD_FILE
  -- Parameters       : p_blob_content - File content as BLOB
  --                    p_file_name - File name to be used for the downloaded file. e.g. demo.zip
  --                    p_mime_type - Used as MIME_HEADER, default value application/octet-stream
  --                    p_disposition - Content-Disposition value, default value attachment
  -- Returns          : n/a
  --

    PROCEDURE download_blob(
        p_blob_content   IN OUT           BLOB
        ,p_file_name      IN               VARCHAR2
        ,p_mime_type      IN               VARCHAR2 DEFAULT 'application/octet-stream'
        ,p_disposition    IN               VARCHAR2 DEFAULT 'attachment'
    )IS
    BEGIN
        IF p_blob_content IS NULL THEN
        -- do nothing
            return;
        END IF;
      -- print headers for file download
        sys.htp.init;
        sys.owa_util.mime_header(
            p_mime_type
            ,false
        );
        sys.htp.p('Content-Length: '
                  || sys.dbms_lob.getlength(p_blob_content));

        sys.htp.p('Content-Disposition: '
                  || p_disposition
                  || '; filename="'
                  || p_file_name
                  || '"');

        sys.owa_util.http_header_close;
      -- start downloading the file
        sys.wpg_docload.download_file(p_blob_content);
    END download_blob;

  -- Name             : get_zip_internal
  -- Description      : function to generate zip file from reference cursor
  -- Parameters       : p_cur_files - SYS_REFCURSOR
  --
  -- Returns          : zip file as BLOB
  --

    FUNCTION get_zip_internal(
        p_cur_files IN   SYS_REFCURSOR
    )RETURN BLOB IS
        l_zip_file       BLOB;
        l_file_name      VARCHAR2(255);
        l_file_content   BLOB;
    BEGIN
        LOOP
            FETCH p_cur_files INTO
                l_file_name
            ,l_file_content;
            EXIT WHEN p_cur_files%notfound;
            apex_zip.add_file(
                p_zipped_blob   => l_zip_file
                ,p_file_name     => l_file_name
                ,p_content       => l_file_content
            );

        END LOOP;

        BEGIN
            apex_zip.finish(p_zipped_blob   => l_zip_file);
        EXCEPTION
            WHEN value_error THEN
        -- if there is no file added so far, then apex_zip.finish raises VALUE_ERROR
        -- do nothing
                NULL;
        END;

        RETURN l_zip_file;
    END get_zip_internal;

  -- Name             : get_zip
  -- Description      : function to generate zip file based on SQL query, uses APEX_ZIP.ADD_FILE
  -- Parameters       : p_sql_query -
  --                      SQL query passed as string with two columns.
  --                      First column should be file_name (VARCHAR2) and second column should be file_content (BLOB)
  --                      e.g. SELECT file_name, file_content FROM files_tables
  --
  -- Returns          : zip file as BLOB
  --

    FUNCTION get_zip(
        p_sql_query IN   VARCHAR2
    )RETURN BLOB IS
        l_zip_file   BLOB;
        c_files      SYS_REFCURSOR;
    BEGIN
        OPEN c_files FOR p_sql_query;

        l_zip_file := get_zip_internal(c_files);
        CLOSE c_files;
        RETURN l_zip_file;
    EXCEPTION
        WHEN OTHERS THEN
            IF c_files%isopen THEN
                CLOSE c_files;
            END IF;
            RAISE;
    END get_zip;

  -- Name             : get_zip
  -- Description      : function to generate zip file based on SQL query, uses APEX_ZIP.ADD_FILE
  -- Parameters       : p_sql_query -
  --                      SQL query passed as string with two columns.
  --                      First column should be file_name (VARCHAR2) and second column should be file_content (BLOB)
  --                      e.g. SELECT file_name, file_content FROM files_tables
  --                    p_bind_1 -
  --                      Value for bind variables used in SQL query.
  -- Returns          : zip file as BLOB
  --

    FUNCTION get_zip(
        p_sql_query   IN            VARCHAR2
        ,p_bind_1      IN            VARCHAR2
    )RETURN BLOB IS
        l_zip_file   BLOB;
        c_files      SYS_REFCURSOR;
    BEGIN
        OPEN c_files FOR p_sql_query
            USING p_bind_1;

        l_zip_file := get_zip_internal(c_files);
        CLOSE c_files;
        RETURN l_zip_file;
    EXCEPTION
        WHEN OTHERS THEN
            IF c_files%isopen THEN
                CLOSE c_files;
            END IF;
            RAISE;
    END get_zip;

  -- Name             : get_zip
  -- Description      : function to generate zip file based on SQL query, uses APEX_ZIP.ADD_FILE
  -- Parameters       : p_sql_query - SQL query passed as string with two columns.
  --                                  First column should be file_name (VARCHAR2) and second column should be file_content (BLOB)
  --                                  e.g. SELECT file_name, file_content FROM files_tables
  --                    p_bind_var_names  - Array of bind variables used in SQL query
  --                    p_bind_var_values - Array of bind variable value used in SQL query
  -- Returns          : zip file as BLOB
  --

    FUNCTION get_zip(
        p_sql_query         IN                  VARCHAR2
        ,p_bind_var_names    IN                  apex_t_varchar2
        ,p_bind_var_values   IN                  apex_t_varchar2
    )RETURN BLOB IS

        l_zip_file         BLOB;
        l_cursor_id        PLS_INTEGER;
        l_execute_output   PLS_INTEGER;
        l_col_count        PLS_INTEGER;
        l_rec_tab          dbms_sql.desc_tab;
        l_file_name        VARCHAR2(255);
        l_file_content     BLOB;
    BEGIN
        -- open a cursor
        l_cursor_id := dbms_sql.open_cursor;
        -- parse input SQL query
        dbms_sql.parse(
            l_cursor_id
            ,p_sql_query
            ,dbms_sql.native
        );
        -- attach bind variables to values
        FOR var_idx IN 1..p_bind_var_names.count LOOP
            dbms_sql.bind_variable(
                l_cursor_id
                ,p_bind_var_names(var_idx)
                ,p_bind_var_values(var_idx)
            );
        END LOOP;
        -- describe the query to find out number of columns and column names

        dbms_sql.describe_columns(
            l_cursor_id
            ,l_col_count
            ,l_rec_tab
        );
        -- define columns
        FOR col_idx IN 1..l_col_count LOOP
            IF l_rec_tab(col_idx).col_type IN(
                dbms_types.typecode_varchar
                ,dbms_types.typecode_varchar2
            )THEN
            -- VARCHAR2
                dbms_sql.define_column(
                    l_cursor_id
                    ,col_idx
                    ,l_file_name
                    ,255
                );
            ELSIF l_rec_tab(col_idx).col_type = dbms_types.typecode_blob THEN
            -- NUMBER
                dbms_sql.define_column(
                    l_cursor_id
                    ,col_idx
                    ,l_file_content
                );
            END IF;
        END LOOP;
        -- execute the SQL query

        l_execute_output := dbms_sql.execute(l_cursor_id);
        -- fetch rows
        WHILE dbms_sql.fetch_rows(l_cursor_id)> 0 LOOP
            FOR col_idx IN 1..l_col_count LOOP
            -- handle different data types
                IF l_rec_tab(col_idx).col_type IN(
                    dbms_types.typecode_varchar
                    ,dbms_types.typecode_varchar2
                )THEN
                -- VARCHAR2
                    dbms_sql.column_value(
                        l_cursor_id
                        ,col_idx
                        ,l_file_name
                    );
                ELSIF l_rec_tab(col_idx).col_type = dbms_types.typecode_blob THEN
                -- BLOB
                    dbms_sql.column_value(
                        l_cursor_id
                        ,col_idx
                        ,l_file_content
                    );
                END IF;
            END LOOP;

            apex_zip.add_file(
                p_zipped_blob   => l_zip_file
                ,p_file_name     => l_file_name
                ,p_content       => l_file_content
            );

        END LOOP;

        -- close cursor

        dbms_sql.close_cursor(l_cursor_id);
        BEGIN
            apex_zip.finish(p_zipped_blob   => l_zip_file);
        EXCEPTION
            WHEN value_error THEN
        -- if there is no file added so far, then apex_zip.finish raises VALUE_ERROR
        -- do nothing
                NULL;
        END;

        RETURN l_zip_file;
    END get_zip;

  -- Name             : get_item_help
  -- Description      : function to get Page Item's help text
  -- Parameters       : p_item_name - Page Item Name
  --                    p_page_id - page number, default to current page
  --                    p_application_id - application number, default to current application
  -- Returns          : Item's help text
  --

    FUNCTION get_item_help(
        p_item_name        IN                 VARCHAR2
        ,p_page_id          IN                 NUMBER DEFAULT NULL
        ,p_application_id   IN                 NUMBER DEFAULT NULL
    )RETURN VARCHAR2 IS
        l_help_text   apex_application_page_items.item_help_text%TYPE;
    BEGIN
        SELECT
            item_help_text
        INTO l_help_text
        FROM
            apex_application_page_items
        WHERE
            item_name = p_item_name
            AND page_id = coalesce(
                p_page_id
                ,nv(
                    'APP_PAGE_ID'
                )
            )
            AND application_id = coalesce(
                p_application_id
                ,nv(
                    'APP_ID'
                )
            );

        RETURN l_help_text;
    EXCEPTION
        WHEN no_data_found THEN
            RETURN 'Invalid Item Name ' || p_item_name;
    END get_item_help;

  -- Name             : get_ig_col_help
  -- Description      : function to get Interactive Grid Column help text
  -- Parameters       : p_col_static_id - IG Column's Static ID
  --                    p_reg_static_id - IG Region's Static ID
  --                    p_page_id - page number, default to current page
  --                    p_application_id - application number, default to current application
  -- Returns          : Interactive Grid Column's help text
  --

    FUNCTION get_ig_col_help(
        p_col_static_id    IN                 VARCHAR2
        ,p_reg_static_id    IN                 VARCHAR2
        ,p_page_id          IN                 NUMBER DEFAULT NULL
        ,p_application_id   IN                 NUMBER DEFAULT NULL
    )RETURN VARCHAR2 IS
        l_help_text   apex_appl_page_ig_columns.help_text%TYPE;
    BEGIN
        SELECT
            cols.help_text
        INTO l_help_text
        FROM
            apex_appl_page_ig_columns cols
            JOIN apex_application_page_regions reg
            ON(reg.region_id = cols.region_id)
        WHERE
            cols.static_id = p_col_static_id
            AND reg.static_id = p_reg_static_id
            AND cols.page_id = coalesce(
                p_page_id
                ,nv(
                    'APP_PAGE_ID'
                )
            )
            AND cols.application_id = coalesce(
                p_application_id
                ,nv(
                    'APP_ID'
                )
            );

        RETURN l_help_text;
    EXCEPTION
        WHEN no_data_found THEN
            RETURN 'Invalid Input. Column Static ID '
                   || p_col_static_id
                   || ', Region Static ID '
                   || p_reg_static_id
                   || ' do not exists.';
    END get_ig_col_help;

END apex_util_wrap;