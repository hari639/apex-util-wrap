CREATE OR REPLACE PACKAGE apex_util_wrap AS
-- Description:
--    Generic functions and procedures which can be used in APEX applications
--
-- Modification History:
-- =====================
-- Date        Author                    Remarks
-- =========== ======================    =======================================================
-- 15-MAY-2020 Srihari Ravva             Initial version

  -- define global variables and constants
    --c_default_date_format CONSTANT VARCHAR2(10):= 'DD-MM-YYYY';
    c_default_list_sep CONSTANT VARCHAR2(1):= ':';
    c_default_no_data_found CONSTANT VARCHAR2(20):= 'No Data Found';
    c_default_more_data_found CONSTANT VARCHAR2(20):= 'More Rows Exists';
    
  -- Name             : merge_placeholders
  -- Description      : function to merge normal placehodlers and table placehodlers (after generating table html)
  --                    returns one placehodlers value which can be used with APEX_MAIL package
  -- Parameters       : p_template_static_id - template static id
  --                    p_placeholders - normal placehodlers of the template
  --                    p_table_placeholders - table placehodlers
  -- Returns          : placehodlers CLOB which can be used with APEX_MAIL package
  --
    FUNCTION merge_placeholders(
        p_template_static_id   IN       VARCHAR2
        ,p_placeholders         IN       CLOB
        ,p_table_placeholders   IN       CLOB
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
        p_template_static_id   IN       VARCHAR2
        ,p_placeholders         IN       CLOB
        ,p_table_placeholders   IN       CLOB
        ,p_to                   IN       VARCHAR2
        ,p_cc                   IN       VARCHAR2 DEFAULT NULL
        ,p_bcc                  IN       VARCHAR2 DEFAULT NULL
        ,p_from                 IN       VARCHAR2 DEFAULT NULL
        ,p_replyto              IN       VARCHAR2 DEFAULT NULL
        ,p_application_id       IN       NUMBER DEFAULT apex_application.g_flow_id
    )RETURN NUMBER;

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
        p_template_static_id   IN       VARCHAR2
        ,p_placeholders         IN       CLOB
        ,p_table_placeholders   IN       CLOB
        ,p_application_id       IN       NUMBER DEFAULT apex_application.g_flow_id
        ,p_subject              OUT      VARCHAR2
        ,p_html                 OUT      CLOB
        ,p_text                 OUT      CLOB
    );
END apex_util_wrap;