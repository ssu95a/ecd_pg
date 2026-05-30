CREATE OR REPLACE PACKAGE ecd_loader_Ret

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   #export off
   DECLARE

      cVersion CONSTANT varchar(100) := '$id: {0.1.0} {10.04.2026} Lora$';

      cTr_Data CONSTANT int4 := 1;
      cTr_Msg  CONSTANT int4 := 2;

   BEGIN
      RAISE DEBUG 'Package "ecd_loader_ret" - % - initialized', cVersion;
   END;
   $init$


/* */
CREATE FUNCTION get_Version( )
   RETURNS varchar
AS
$function$
BEGIN
   RETURN cVersion;
END;
$function$


/* */
CREATE PROCEDURE ensure_Table( )
AS
$procedure$
   #private
BEGIN
   CREATE TEMP TABLE IF NOT EXISTS ecd_ret (
      itr   numeric       NOT NULL,
      cent  varchar(20),
      ci_id varchar(20),
      ce_id varchar(100),
      ctext varchar(2000)
   )
   ON COMMIT PRESERVE ROWS;
END;
$procedure$


/* */   
CREATE PROCEDURE ret_Init()
AS
$procedure$
BEGIN
   CALL ensure_table();
END;
$procedure$


/* */
CREATE PROCEDURE ret_Clear()
AS
$procedure$
BEGIN
   CALL ensure_table();
   DELETE FROM ecd_ret;
END;
$procedure$


/* */
CREATE PROCEDURE put_Msg (
   p_ent_id varchar,
   p_text   varchar,
   p_ext_id varchar DEFAULT NULL,
   p_int_id varchar DEFAULT NULL
)
AS
$procedure$
   #private
BEGIN
   CALL ensure_table();

   INSERT INTO ecd_ret(itr, cent, ci_id, ce_id, ctext)
   VALUES (cTr_Msg, p_ent_id, p_int_id, p_ext_id, p_text);
END;
$procedure$

/* */
CREATE PROCEDURE put_Data(
   p_ent_id varchar,
   p_ext_id varchar,
   p_int_id varchar
)
AS
$procedure$
BEGIN
   CALL ensure_table();

   IF p_ent_id IS NOT NULL AND p_int_id IS NOT NULL THEN
      INSERT INTO ecd_ret(itr, cent, ci_id, ce_id)
      VALUES (cTR_Data, p_ent_id, p_int_id, p_ext_id);
   END IF;
END;
$procedure$


CREATE PROCEDURE put_Info(
   p_ent_id varchar,
   p_text   varchar,
   p_ext_id varchar DEFAULT NULL,
   p_int_id varchar DEFAULT NULL
)
AS
$procedure$
BEGIN
   CALL put_Msg( p_ent_id, p_text, p_ext_id, p_int_id );
END;
$procedure$

/* */
CREATE PROCEDURE put_Warn (
   p_ent_id varchar,
   p_text   varchar,
   p_ext_id varchar DEFAULT NULL,
   p_int_id varchar DEFAULT NULL
)
AS
$procedure$
BEGIN
   CALL put_Msg(p_ent_id, '[WRN] ' || p_text, p_ext_id, p_int_id);
END;
$procedure$

/* */
CREATE PROCEDURE put_Error(
   p_ent_id varchar,
   p_text   varchar,
   p_ext_id varchar DEFAULT NULL,
   p_int_id varchar DEFAULT NULL
)
AS
$procedure$
BEGIN
   CALL put_Msg(p_ent_id, '[ERR] ' || p_text, p_ext_id, p_int_id);
END;
$procedure$


CREATE FUNCTION rec_Count( )
   RETURNS numeric
AS
$function$
DECLARE
   l_cnt numeric;
BEGIN
   CALL ensure_table();

   SELECT count(*)
     INTO l_cnt
     FROM ecd_ret;

   RETURN l_cnt;
END;
$function$

--end_Of_Package
;