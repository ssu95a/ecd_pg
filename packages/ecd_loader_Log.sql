CREATE OR REPLACE PACKAGE ECD_loader_Log

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   DECLARE
      
      cVersion CONSTANT varchar(100) := '$id: {0.2.0} {02.06.2026} Lora$';

      cLevel_Trc CONSTANT varchar(3) := 'trc';
      cLevel_Dbg CONSTANT varchar(3) := 'dbg';
      cLevel_Inf CONSTANT varchar(3) := 'inf';
      cLevel_Wrn CONSTANT varchar(3) := 'wrn';
      cLevel_Err CONSTANT varchar(3) := 'err';

   BEGIN
      RAISE DEBUG 'Package "ECD_loader_Log" - % - initialized', cVersion;
   END;
   $init$


/* */
CREATE FUNCTION get_Version()
   RETURNS varchar
AS
$function$
   #package
BEGIN
   RETURN cVersion;
END;
$function$


/* */
CREATE PROCEDURE log(
   in p_level varchar,
   in p_text  varchar
)
AS
$procedure$
   #package
BEGIN
   CALL ECD_loader_Log.log( p_level, p_text, null::varchar, null::varchar );
END;
$procedure$


/* вариант с уровнем */
CREATE PROCEDURE log (
   in p_level varchar,
   in p_proc  varchar,
   in p_phase varchar,
   in p_text  varchar DEFAULT NULL
)
AS
$procedure$
   #package
BEGIN
   RAISE DEBUG 'ecd - [%] %: % %', coalesce( p_level, 'dbg'), coalesce( p_proc,'<proc?>'), coalesce(p_phase, '<phase?>'), coalesce(' | ' || NULLIF(p_text, ''), '');
END;
$procedure$

/* */
CREATE PROCEDURE trc(
   in p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL ECD_loader_Log.log(cLevel_Trc, p_text, null::varchar);
END;
$procedure$


/* */
CREATE PROCEDURE dbg(
   in p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL ECD_loader_Log.log(cLevel_Dbg, p_text, null::varchar);
END;
$procedure$


/* */
CREATE PROCEDURE inf (
   in p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL ECD_loader_Log.log(cLevel_Inf, p_text, null::varchar);
END;
$procedure$


/* */
CREATE PROCEDURE wrn(
   in p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL ECD_loader_Log.log(cLevel_Wrn, p_text, null::varchar);
END;
$procedure$


/* */
CREATE PROCEDURE err(
   in p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL ECD_loader_Log.log(cLevel_Err, p_text, null::varchar);
END;
$procedure$


/* */
CREATE PROCEDURE dbg(
   in p_proc    varchar,
   in p_phase   varchar,
   in p_text varchar DEFAULT NULL
)
AS
$procedure$
   #package
BEGIN
   CALL ECD_loader_Log.log(cLevel_Dbg, p_proc, p_phase, p_text);
END;
$procedure$


/* */
CREATE PROCEDURE inf(
   p_proc    varchar,
   p_phase   varchar,
   p_text varchar DEFAULT NULL
)
AS
$procedure$
   #package
BEGIN
   CALL ECD_loader_Log.log(cLevel_Inf, p_proc, p_phase, p_text);
END;
$procedure$


/* */
CREATE PROCEDURE wrn(
   p_proc    varchar,
   p_phase   varchar,
   p_text varchar DEFAULT NULL
)
AS
$procedure$
   #package
BEGIN
   CALL ECD_loader_Log.log(cLevel_Wrn, p_proc, p_phase, p_text);
END;
$procedure$


/* */
CREATE PROCEDURE err(
   p_proc    varchar,
   p_phase   varchar,
   p_text varchar DEFAULT NULL
)
AS
$procedure$
   #package
BEGIN
   CALL ECD_loader_Log.log(cLevel_Err, p_proc, p_phase, p_text);
END;
$procedure$

;