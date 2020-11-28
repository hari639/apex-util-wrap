CREATE OR REPLACE PACKAGE apex_util_wrap AS
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

  -- define global variables and constants
    --c_default_date_format CONSTANT VARCHAR2(10):= 'DD-MM-YYYY';
    c_default_list_sep CONSTANT VARCHAR2(1):= ':';
    c_default_no_data_found CONSTANT VARCHAR2(20):= 'No Data Found';
    c_default_more_data_found CONSTANT VARCHAR2(20):= 'More Rows Exists';

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
    )RETURN CLOB;

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
    )RETURN NUMBER;

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
    );

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
    );

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
    );

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
    )RETURN BLOB;

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
    )RETURN BLOB;

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
    )RETURN BLOB;

  -- Name             : get_item_help
  -- Description      : function to get Page Item's help text
  -- Parameters       : p_item_name - Page Item Name
  --                    p_page_id - Page number, default to current page
  --                    p_application_id - Application number, default to current application
  -- Returns          : Item's help text
  --

    FUNCTION get_item_help(
        p_item_name        IN                 VARCHAR2
        ,p_page_id          IN                 NUMBER DEFAULT NULL
        ,p_application_id   IN                 NUMBER DEFAULT NULL
    )RETURN VARCHAR2;

  -- Name             : get_ig_col_help
  -- Description      : function to get Interactive Grid Column help text
  -- Parameters       : p_col_static_id - IG Column's Static ID
  --                    p_reg_static_id - IG Region's Static ID
  --                    p_page_id - Page number, default to current page
  --                    p_application_id - Application number, default to current application
  -- Returns          : Interactive Grid Column's help text
  --

    FUNCTION get_ig_col_help(
        p_col_static_id    IN                 VARCHAR2
        ,p_reg_static_id    IN                 VARCHAR2
        ,p_page_id          IN                 NUMBER DEFAULT NULL
        ,p_application_id   IN                 NUMBER DEFAULT NULL
    )RETURN VARCHAR2;

END apex_util_wrap;