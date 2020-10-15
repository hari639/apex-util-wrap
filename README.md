# Oracle APEX Utility APIs

APEX_UTIL_WRAP contains generic functions and procedures which can be used in APEX applications. Some of the functions and procedures are wrappers on Oracle APEX PL/SQL APIs and thus the name APEX_UTIL_WRAP.

## APIs

**MERGE_PLACEHOLDERS Function**

Function to merge normal placeholders and tabular placeholders after generating html table(s). Returns one placeholders value which can be used with APEX_MAIL package.

_Syntax_

```sql
    FUNCTION merge_placeholders(
        p_placeholders         IN       CLOB
        ,p_table_placeholders   IN       CLOB
    )RETURN CLOB;
```

_Parameters_

  | Parameter | Description |
  | ------ | ------ |
  |p_placeholders|JSON string representing the placeholder names along with the values, to be substituted.|
  |p_table_placeholders|JSON string representing the placeholder definition to generate HTML tabular data. Please refer below for sample JSON format.|
  
p_table_placeholders sample JSON format:

```js
{
  "tables":[
    {
      "substitution_string":"EMP_DATA_TABLE",
      "sql_query":"SELECT * FROM EMP WHERE JOB = :JOB OR ENAME = :ENAME",
      "bind_var_names":"JOB:ENAME",
      "bind_var_values":"MANAGER:KING",
      "limit_rows":"5",
      "no_data_found":"No employees exists",
      "more_data_found":"There are more employees exists, however only 5 employees are displayed here. Please login to application to see all employees."
    }
  ]
}
```

_Example_

```sql
DECLARE
    l_placeholders         CLOB;
    l_table_placeholders   CLOB;
    l_sql_query            VARCHAR2(4000);
BEGIN
    -- build normal placeholders used in email templates
    apex_json.initialize_clob_output;
    apex_json.open_object;
    FOR dept IN(
        SELECT
            deptno
            ,dname
        FROM
            auw_dept
        WHERE
            deptno = :P2_DEPTNO
    )LOOP
        apex_json.write(
            'DEPTNO'
            ,dept.deptno
        );
        apex_json.write(
            'DNAME'
            ,dept.dname
        );
    END LOOP;
    apex_json.close_object;
    l_placeholders := apex_json.get_clob_output;
    apex_json.free_output;
    --
    -- build table placeholders
    --
    apex_json.initialize_clob_output;
    apex_json.open_object;
    apex_json.open_array('tables');
    --
    -- begin table code
    --
    -- repeat below for each tabular substitution_string defined in email template
    --
    -- EMP_DATA_TABLE -- start
    apex_json.open_object;
    l_sql_query := 'select empno "Emp #", ename "Name", job "Job", hiredate "Hire Date", sal "Salary $" from auw_emp where deptno = :DEPTNO';
    apex_json.write(
        'substitution_string'
        ,'EMP_DATA_TABLE'
    );
    apex_json.write(
        'sql_query'
        ,l_sql_query
    );
    -- colon seperated bind variable names
    -- Optional if your query does not have any bind variables
    apex_json.write(
        'bind_var_names'
        ,'DEPTNO'
    );
    -- colon seperated bind variable values
    -- Optional if your query does not have any bind variables
    apex_json.write(
        'bind_var_values'
        ,:P2_DEPTNO
    );
    -- Specify '' to display all the rows
    -- Optional if you don't want to limit output rows
    apex_json.write(
        'limit_rows'
        ,'5'
    );
    -- Optional if you don't want to use custom message for no_data_found
    apex_json.write(
        'no_data_found'
        ,'No employees found for this department.'
    );
    -- Optional if you have not specified any value for limit_rows
    -- or if you don't want to use custom message for more_data_found
    apex_json.write(
        'more_data_found'
        ,'There are more employees for this department. Please log into the application to see all employees.'
    );
    apex_json.close_object;
    --
    -- EMP_DATA_TABLE -- end
    --
    apex_json.close_array;
    apex_json.close_object;
    l_table_placeholders := apex_json.get_clob_output;
    apex_json.free_output;
    --
    -- merge normal placeholders and tabular place holders
    --
    l_placeholders := apex_util_wrap.merge_placeholders(
        p_placeholders         => l_placeholders
        ,p_table_placeholders  => l_table_placeholders
    );
    --
    -- Send Email as usual using APEX_MAIL package
    --
    apex_mail.send(
        p_to                    => 'someone@somewhere.com'
        ,p_template_static_id   => 'TABULAR_DATA_DEMO'
        ,p_placeholders         => l_placeholders
    );
    apex_mail.push_queue;
END;
```

**SEND_MAIL Function**

Function to send email using Email templates that includes tabular data, calls APEX_MAIL.SEND function internally. Returns mail_id, using which attachments can be added using APEX_MAIL.ADD_ATTACHMENT API.

_Syntax_

```sql
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
```

_Parameters_

All parameters are same as in APEX_MAIL.SEND function. Only additional parameter is p_table_placeholders which is explained at MERGE_PLACEHOLDERS function.

_Example_

```sql
DECLARE
    l_placeholders         CLOB;
    l_table_placeholders   CLOB;
    l_sql_query            VARCHAR2(4000);
    l_mail_id              NUMBER;
BEGIN
    -- build normal placeholders used in email templates
    apex_json.initialize_clob_output;
    apex_json.open_object;
    FOR dept IN(
        SELECT
            deptno
            ,dname
        FROM
            auw_dept
        WHERE
            deptno = :P3_DEPTNO
    )LOOP
        apex_json.write(
            'DEPTNO'
            ,dept.deptno
        );
        apex_json.write(
            'DNAME'
            ,dept.dname
        );
    END LOOP;
    apex_json.close_object;
    l_placeholders := apex_json.get_clob_output;
    apex_json.free_output;
    --
    -- build table placeholders
    --
    apex_json.initialize_clob_output;
    apex_json.open_object;
    apex_json.open_array('tables');
    --
    -- begin table code
    --
    -- repeat below for each tabular substitution_string defined in email template
    --
    -- EMP_DATA_TABLE -- start
    apex_json.open_object;
    l_sql_query := 'select empno "Emp #", ename "Name", job "Job", hiredate "Hire Date", sal "Salary $" from auw_emp where deptno = :DEPTNO';
    apex_json.write(
        'substitution_string'
        ,'EMP_DATA_TABLE'
    );
    apex_json.write(
        'sql_query'
        ,l_sql_query
    );
    -- colon seperated bind variable names
    -- Optional if your query does not have any bind variables
    apex_json.write(
        'bind_var_names'
        ,'DEPTNO'
    );
    -- colon seperated bind variable values
    -- Optional if your query does not have any bind variables
    apex_json.write(
        'bind_var_values'
        ,:P3_DEPTNO
    );
    -- Specify '' to display all the rows
    -- Optional if you don't want to limit output rows
    apex_json.write(
        'limit_rows'
        ,'3'
    );
    -- Optional if you don't want to use custom message for no_data_found
    apex_json.write(
        'no_data_found'
        ,'No employees found for this department.'
    );
    -- Optional if you have not specified any value for limit_rows
    -- or if you don't want to use custom message for more_data_found
    apex_json.write(
        'more_data_found'
        ,'There are more employees for this department. Please log into the application to see all employees.'
    );
    apex_json.close_object;
    --
    -- EMP_DATA_TABLE -- end
    --
    apex_json.close_array;
    apex_json.close_object;
    l_table_placeholders := apex_json.get_clob_output;
    apex_json.free_output;
    --
    -- Send Email as usual using APEX_UTIL_WRAP package
    -- if you want to include attachments, then use send_mail function instead
    --
    l_mail_id := apex_util_wrap.send_mail(
        p_to                    => 'someone@somewhere.com'
        ,p_template_static_id   => 'TABULAR_DATA_DEMO'
        ,p_placeholders         => l_placeholders
        ,p_table_placeholders   => l_table_placeholders
    );
    
    apex_mail.add_attachment (
        p_mail_id    => l_mail_id,
        p_attachment => ... );    
    
    apex_mail.push_queue;
END;
```

**SEND_MAIL Procedure**

Procedure to send email using Email templates that includes tabular data, calls APEX_UTIL_WRAP.SEND_MAIL function internally. 

_Syntax_

```sql
    PROCEDURE send_mail(
        p_template_static_id   IN       VARCHAR2
        ,p_placeholders         IN       CLOB
        ,p_table_placeholders   IN       CLOB
        ,p_to                   IN       VARCHAR2
        ,p_cc                   IN       VARCHAR2 DEFAULT NULL
        ,p_bcc                  IN       VARCHAR2 DEFAULT NULL
        ,p_from                 IN       VARCHAR2 DEFAULT NULL
        ,p_replyto              IN       VARCHAR2 DEFAULT NULL
        ,p_application_id       IN       NUMBER DEFAULT apex_application.g_flow_id
    );
```

_Parameters_

All parameters are same as in APEX_MAIL.SEND procedures. Only additional parameter is p_table_placeholders which is explained at MERGE_PLACEHOLDERS function.

_Example_

```sql
DECLARE
    l_placeholders         CLOB;
    l_table_placeholders   CLOB;
    l_sql_query            VARCHAR2(4000);
BEGIN
    -- build normal placeholders used in email templates
    apex_json.initialize_clob_output;
    apex_json.open_object;
    FOR dept IN(
        SELECT
            deptno
            ,dname
        FROM
            auw_dept
        WHERE
            deptno = :P3_DEPTNO
    )LOOP
        apex_json.write(
            'DEPTNO'
            ,dept.deptno
        );
        apex_json.write(
            'DNAME'
            ,dept.dname
        );
    END LOOP;
    apex_json.close_object;
    l_placeholders := apex_json.get_clob_output;
    apex_json.free_output;
    --
    -- build table placeholders
    --
    apex_json.initialize_clob_output;
    apex_json.open_object;
    apex_json.open_array('tables');
    --
    -- begin table code
    --
    -- repeat below for each tabular substitution_string defined in email template
    --
    -- EMP_DATA_TABLE -- start
    apex_json.open_object;
    l_sql_query := 'select empno "Emp #", ename "Name", job "Job", hiredate "Hire Date", sal "Salary $" from auw_emp where deptno = :DEPTNO';
    apex_json.write(
        'substitution_string'
        ,'EMP_DATA_TABLE'
    );
    apex_json.write(
        'sql_query'
        ,l_sql_query
    );
    -- colon seperated bind variable names
    -- Optional if your query does not have any bind variables
    apex_json.write(
        'bind_var_names'
        ,'DEPTNO'
    );
    -- colon seperated bind variable values
    -- Optional if your query does not have any bind variables
    apex_json.write(
        'bind_var_values'
        ,:P3_DEPTNO
    );
    -- Specify '' to display all the rows
    -- Optional if you don't want to limit output rows
    apex_json.write(
        'limit_rows'
        ,'3'
    );
    -- Optional if you don't want to use custom message for no_data_found
    apex_json.write(
        'no_data_found'
        ,'No employees found for this department.'
    );
    -- Optional if you have not specified any value for limit_rows
    -- or if you don't want to use custom message for more_data_found
    apex_json.write(
        'more_data_found'
        ,'There are more employees for this department. Please log into the application to see all employees.'
    );
    apex_json.close_object;
    --
    -- EMP_DATA_TABLE -- end
    --
    apex_json.close_array;
    apex_json.close_object;
    l_table_placeholders := apex_json.get_clob_output;
    apex_json.free_output;
    --
    -- Send Email as usual using APEX_UTIL_WRAP package
    -- if you want to include attachments, then use send_mail function instead
    --
    l_mail_id := apex_util_wrap.send_mail(
        p_to                    => 'someone@somewhere.com'
        ,p_template_static_id   => 'TABULAR_DATA_DEMO'
        ,p_placeholders         => l_placeholders
        ,p_table_placeholders   => l_table_placeholders
    );   
    
    apex_mail.push_queue;
END;
```

**PREVIEW_TEMPLATE Procedure**

Procedure to preview email template output, it is based on APEX_MAIL.PREPARE_TEMPLATE API. Returns p_subject, p_html and p_text as OUT parameters, same as APEX_MAIL.PREPARE_TEMPLATE API.

_Syntax_

```sql
    PROCEDURE preview_template(
        p_template_static_id   IN       VARCHAR2
        ,p_placeholders         IN       CLOB
        ,p_table_placeholders   IN       CLOB
        ,p_application_id       IN       NUMBER DEFAULT apex_application.g_flow_id
        ,p_subject              OUT      VARCHAR2
        ,p_html                 OUT      CLOB
        ,p_text                 OUT      CLOB
    );
```

_Parameters_

All parameters are same as in APEX_MAIL.PREPARE_TEMPLATE procedure. Only additional parameter is p_table_placeholders which is explained at MERGE_PLACEHOLDERS function.

_Example_

```sql
DECLARE
    l_placeholders         CLOB;
    l_table_placeholders   CLOB;
    l_sql_query            VARCHAR2(4000);
BEGIN
    -- build normal placeholders
    apex_json.initialize_clob_output;
    apex_json.open_object;
    FOR dept IN(
        SELECT
            deptno
            ,dname
        FROM
            auw_dept
        WHERE
            deptno = :P4_DEPTNO
    )LOOP
        apex_json.write(
            'DEPTNO'
            ,dept.deptno
        );
        apex_json.write(
            'DNAME'
            ,dept.dname
        );
    END LOOP;
    apex_json.close_object;
    l_placeholders := apex_json.get_clob_output;
    apex_json.free_output;
    --
    -- build table placeholders
    --
    apex_json.initialize_clob_output;
    apex_json.open_object;
    apex_json.open_array('tables');
    --
    -- begin table code
    --
    -- repeat below for each tabular substitution_string defined in email template
    --
    -- EMP_DATA_TABLE -- start
    apex_json.open_object;
    l_sql_query := 'select empno "Emp #", ename "Name", job "Job", hiredate "Hire Date", sal "Salary $" from auw_emp where deptno = :DEPTNO';
    apex_json.write(
        'substitution_string'
        ,'EMP_DATA_TABLE'
    );
    apex_json.write(
        'sql_query'
        ,l_sql_query
    );
    -- colon seperated bind variable names
    -- Optional if your query does not have any bind variables
    apex_json.write(
        'bind_var_names'
        ,'DEPTNO'
    );
    -- colon seperated bind variable values
    -- Optional if your query does not have any bind variables
    apex_json.write(
        'bind_var_values'
        ,:P4_DEPTNO
    );
    -- Specify '' to display all the rows
    -- Optional if you don't want to limit output rows
    apex_json.write(
        'limit_rows'
        ,'5'
    );
    -- Optional if you don't want to use custom message for no_data_found
    apex_json.write(
        'no_data_found'
        ,'No employees found for this department.'
    );
    -- Optional if you have not specified any value for limit_rows
    -- or if you don't want to use custom message for more_data_found
    apex_json.write(
        'more_data_found'
        ,'There are more employees for this department. Please log into the application to see all employees.'
    );
    apex_json.close_object;
    --
    -- EMP_DATA_TABLE -- end
    --
    apex_json.close_array;
    apex_json.close_object;
    l_table_placeholders := apex_json.get_clob_output;
    apex_json.free_output;
    --
    -- merge normal placeholders and tabular place holders
    --
    l_placeholders := apex_util_wrap.merge_placeholders(
        p_placeholders         => l_placeholders
        ,p_table_placeholders  => l_table_placeholders
    );
    --
    -- Preview Email
    --
    apex_util_wrap.preview_template (
        p_template_static_id => 'TABULAR_DATA_DEMO'
        ,p_placeholders       => l_placeholders
        ,p_table_placeholders => l_table_placeholders
        ,p_subject            => :P4_SUBJECT
        ,p_html               => :P4_HTML
        ,p_text               => :P4_TEXT
    );
END;
```

## How to Install Demo Application
  * Import the application into APEX workspace and follow the wizard. This application also contains supporting objects and sample data.
  * Demo APEX application exported from APEX version 20.2
  * Primary objects installed as part of supporting objects

  | Object Name | Object Type |
  | ------ | ------ |
  |AUW_DEPT|TABLE|
  |AUW_EMP|TABLE|
  |AUW_PRODUCTS|TABLE|
  |AUW_SAMPLE_DATA_PKG|PACKAGE|
  |AUW_SAMPLE_DATA_PKG|PACKAGE BODY|
  
  * Demo application [link](https://apex.oracle.com/pls/apex/f?p=70896:1:). Username DEMO, Password DEMODEMO
  
## Further Reading

[Email Templates with Tabular Data](https://srihariravva.blogspot.com/2020/05/email-templates-tabular-data.html)