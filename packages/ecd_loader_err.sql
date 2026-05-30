CREATE OR REPLACE PACKAGE ecd_loader_err

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   #export off
   DECLARE

      cVersion CONSTANT varchar(100) := '$id: {0.1.0} {10.04.2026} Lora$';

      cErr_Prefix_Business CONSTANT varchar(30) := 'ECD_BUS_';
      cErr_Prefix_Config   CONSTANT varchar(30) := 'ECD_CFG_';
      cErr_Prefix_Data     CONSTANT varchar(30) := 'ECD_DAT_';

      g_last_error_text varchar(4000 ) := NULL;
      g_last_error_full varchar(32000) := NULL;

   BEGIN
      RAISE DEBUG 'Package "ecd_loader_err" - % - initialized', cVersion;
   END;
   $init$

   CREATE FUNCTION get_Version()
      RETURNS varchar
   AS
   $function$
   BEGIN
      RETURN cVersion;
   END;
   $function$

   CREATE PROCEDURE clear_last_error()
   AS
   $procedure$
   BEGIN
      g_last_error_text := NULL;
      g_last_error_full := NULL;
   END;
   $procedure$

   CREATE FUNCTION get_last_error_text()
      RETURNS varchar
   AS
   $function$
   BEGIN
      RETURN g_last_error_text;
   END;
   $function$

   CREATE FUNCTION get_last_error_full()
      RETURNS varchar
   AS
   $function$
   BEGIN
      RETURN g_last_error_full;
   END;
   $function$

   CREATE PROCEDURE set_last_error(
      p_text varchar,
      p_full varchar DEFAULT NULL
   )
   AS
   $procedure$
   #private
   BEGIN
      g_last_error_text := p_text;
      g_last_error_full := coalesce(p_full, p_text);
   END;
   $procedure$

   CREATE PROCEDURE raise_business_error(
      p_code    varchar,
      p_message varchar
   )
   AS
   $procedure$
   DECLARE
      l_hint varchar(4000);
   BEGIN
      l_hint := cErr_Prefix_Business || coalesce(p_code, 'UNKNOWN');

      CALL set_last_error(p_message, p_message);
      CALL ecd_loader_log.err('BUSINESS ERROR [' || l_hint || '] ' || coalesce(p_message, '<empty>'));

      RAISE EXCEPTION '%', coalesce(p_message, 'Business error')
         USING ERRCODE = 'P0001',
               HINT    = l_hint;
   END;
   $procedure$

   CREATE PROCEDURE raise_config_error(
      p_code    varchar,
      p_message varchar
   )
   AS
   $procedure$
   DECLARE
      l_hint varchar(4000);
   BEGIN
      l_hint := cErr_Prefix_Config || coalesce(p_code, 'UNKNOWN');

      CALL set_last_error(p_message, p_message);
      CALL ecd_loader_log.err('CONFIG ERROR [' || l_hint || '] ' || coalesce(p_message, '<empty>'));

      RAISE EXCEPTION '%', coalesce(p_message, 'Configuration error')
         USING ERRCODE = 'P0001',
               HINT    = l_hint;
   END;
   $procedure$

   CREATE PROCEDURE raise_data_error(
      p_code    varchar,
      p_message varchar
   )
   AS
   $procedure$
   DECLARE
      l_hint varchar(4000);
   BEGIN
      l_hint := cErr_Prefix_Data || coalesce(p_code, 'UNKNOWN');

      CALL set_last_error(p_message, p_message);
      CALL ecd_loader_log.err('DATA ERROR [' || l_hint || '] ' || coalesce(p_message, '<empty>'));

      RAISE EXCEPTION '%', coalesce(p_message, 'Data error')
         USING ERRCODE = 'P0001',
               HINT    = l_hint;
   END;
   $procedure$

   CREATE PROCEDURE capture_unhandled(
      p_scope varchar,
      OUT p_text varchar
   )
   AS
   $procedure$
   DECLARE
      l_state   varchar(10);
      l_msg     varchar(4000);
      l_detail  varchar(4000);
      l_hint    varchar(4000);
      l_context varchar(4000);
      l_full    varchar(32000);
   BEGIN
      GET STACKED DIAGNOSTICS
         l_state   = RETURNED_SQLSTATE,
         l_msg     = MESSAGE_TEXT,
         l_detail  = PG_EXCEPTION_DETAIL,
         l_hint    = PG_EXCEPTION_HINT,
         l_context = PG_EXCEPTION_CONTEXT;

      p_text := '[' || coalesce(p_scope, '<unknown>') || '] ' || coalesce(l_msg, 'Unhandled error');

      l_full :=
            p_text
         || chr(10) || 'SQLSTATE: ' || coalesce(l_state, '<null>')
         || chr(10) || 'DETAIL: '   || coalesce(l_detail, '<null>')
         || chr(10) || 'HINT: '     || coalesce(l_hint, '<null>')
         || chr(10) || 'CONTEXT: '  || coalesce(l_context, '<null>');

      CALL set_last_error(p_text, l_full);
      CALL ecd_loader_log.err(l_full);
   END;
   $procedure$

;