use role accountadmin;


-- Create roles
create role snowflake_intelligence_admin_rl;
create role snowflake_intelligence_modeling_rl;
grant role snowflake_intelligence_modeling_rl to role snowflake_intelligence_admin_rl;
grant role snowflake_intelligence_admin_rl to role accountadmin;


create role snowflake_intelligence_ro_rl;
grant role snowflake_intelligence_ro_rl to role snowflake_intelligence_modeling_rl;


-- Warehouse that is going to be used for Cortex Search Service creation as well as query execution.
create warehouse snowflake_intelligence_wh with warehouse_size = 'X-SMALL';
grant usage,operate on warehouse snowflake_intelligence_wh to role snowflake_intelligence_admin_rl;
grant usage,operate on warehouse snowflake_intelligence_wh to role snowflake_intelligence_modeling_rl;
grant usage,operate on warehouse snowflake_intelligence_wh to role snowflake_intelligence_ro_rl;


-- Create a database. This will hold configuration and other objects to support Snowflake Intelligence.
create database snowflake_intelligence;
grant ownership on database snowflake_intelligence to role snowflake_intelligence_admin_rl;


-- Dynamically grant role 'snowflake_intelligence_admin_rl' to the current user
DECLARE
    sql_command STRING;
BEGIN
    sql_command := 'GRANT ROLE snowflake_intelligence_admin_rl TO USER "' || CURRENT_USER() || '";';
    EXECUTE IMMEDIATE sql_command;
    RETURN 'Role snowflake_intelligence_admin_rl granted successfully to user ' || CURRENT_USER();
END;


-- Set up stages and tables for configuration.
use role snowflake_intelligence_admin_rl;
use database snowflake_intelligence;


-- Set up a temp schema for file upload (only temporary stages will be created here).
create or replace schema snowflake_intelligence.temp;
grant usage on schema snowflake_intelligence.temp to role public;


-- OPTIONAL: Set up stages and tables for configuration - you can have your semantic models be anywhere else, just make sure that the users have grants to them
create schema if not exists config;
grant usage on schema config to role snowflake_intelligence_modeling_rl;
grant usage on schema config to role snowflake_intelligence_ro_rl;
use schema config;


create stage semantic_models encryption = (type = 'SNOWFLAKE_SSE');
grant read on stage snowflake_intelligence.config.semantic_models to role snowflake_intelligence_modeling_rl;
grant read on stage snowflake_intelligence.config.semantic_models to role snowflake_intelligence_ro_rl;


---- 
-- Script 2
----

use role snowflake_intelligence_admin_rl;
create schema if not exists snowflake_intelligence.agents;


-- Make SI agents in general discoverable to everyone.
grant usage on schema snowflake_intelligence.agents to role public;


CREATE OR REPLACE ROW ACCESS POLICY snowflake_intelligence.agents.agent_policy
AS (grantee_roles ARRAY) RETURNS BOOLEAN -> 
  ARRAY_SIZE(FILTER(grantee_roles::ARRAY(VARCHAR), role -> is_role_in_session(role))) <> 0;


-- Create an agent config table. Multiple tables can be created to give granular
-- UPDATE/INSERT permissions to different roles.
create or replace table snowflake_intelligence.agents.config (
   agent_name varchar not null,
   agent_description varchar,
   grantee_roles array not null,
   tools array,
   tool_resources object,
   tool_choice object,
   response_instruction varchar,
   sample_questions array,
   constraint pk_agent_name primary key (agent_name)
)
with row access policy snowflake_intelligence.agents.agent_policy on (grantee_roles);
grant select on table snowflake_intelligence.agents.config to role public;
grant update on table snowflake_intelligence.agents.config to role snowflake_intelligence_modeling_rl;

----
-- Script 3
----

use role snowflake_intelligence_admin_rl;
create schema snowflake_intelligence.logs;
grant usage on schema snowflake_intelligence.logs to role snowflake_intelligence_ro_rl;




create or replace table snowflake_intelligence.logs.feedback (
   entity_type varchar not null,
   username varchar not null,
   agent_name varchar not null,
   agent_session_id varchar not null,
   context variant not null,
   feedback_timestamp datetime not null,
   feedback_categories variant,
   feedback_message varchar,
   message_id varchar,
   feedback_sentiment varchar,
   user_prompt variant,
   executed_queries array,
   documents_returned array,
   response_start_timestamp datetime,
   response_end_timestamp datetime,
   response_duration number
);




grant insert on table snowflake_intelligence.logs.feedback to role public;
