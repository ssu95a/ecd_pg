CREATE OR REPLACE PACKAGE ecd_loader_log

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   #export off
   DECLARE
      
      cVersion CONSTANT varchar(100) := '$id: {0.1.1} {10.04.2026} Lora$';

      cMode_Off        CONSTANT int4 := 0;
      cMode_Raise_Only CONSTANT int4 := 1;
      cMode_All        CONSTANT int4 := 2;

      cLevel_Trc CONSTANT bpchar(3) := 'trc';
      cLevel_Dbg CONSTANT bpchar(3) := 'dbg';
      cLevel_Inf CONSTANT bpchar(3) := 'inf';
      cLevel_Wrn CONSTANT bpchar(3) := 'wrn';
      cLevel_Err CONSTANT bpchar(3) := 'err';

      g_mode          int4      := cMode_All;
      g_default_level bpchar(3) := cLevel_Dbg;

   BEGIN
      RAISE DEBUG 'Package "ecd_loader_log" - % - initialized', cVersion;
   END;
   $init$


/* */
CREATE FUNCTION get_version()
   RETURNS varchar
AS
$function$
   #package
BEGIN
   RETURN cVersion;
END;
$function$


/* */
CREATE FUNCTION get_mode()
   RETURNS int4
AS
$function$
   #package
BEGIN
   RETURN g_mode;
END;
$function$


/* */
CREATE PROCEDURE set_mode(
   p_mode int4
)
AS
$procedure$
   #package
BEGIN
   IF p_mode NOT IN (cMode_Off, cMode_Raise_Only, cMode_All) THEN
      RAISE EXCEPTION 'Недопустимый режим логирования: %', p_mode;
   END IF;

   g_mode := p_mode;

END;
$procedure$


/* */
CREATE FUNCTION get_Default_Level( )
   RETURNS bpchar
AS
$function$
   #package
BEGIN
   RETURN g_default_level;
END;
$function$


/* */
CREATE PROCEDURE set_default_level(
   p_level bpchar
)
AS
$procedure$
   #package
BEGIN
   IF p_level NOT IN (cLevel_Trc, cLevel_Dbg, cLevel_Inf, cLevel_Wrn, cLevel_Err) THEN
      RAISE EXCEPTION 'Недопустимый уровень логирования: %', p_level;
   END IF;

   g_default_level := p_level;
END;
$procedure$


/* */
CREATE PROCEDURE log(
   p_text varchar
)
AS
$procedure$
   #package
   BEGIN
   CALL log(g_default_level, p_text);
END;
$procedure$

/* */
CREATE PROCEDURE log(
   p_level bpchar,
   p_text  varchar
)
AS
$procedure$
   #package
   #private
BEGIN
   IF g_mode = cMode_Off THEN
      RETURN;
   END IF;

   IF g_mode = cMode_Raise_Only AND p_level <> cLevel_Err THEN
      RETURN;
   END IF;

   CASE p_level
      WHEN cLevel_Trc THEN
         RAISE DEBUG   'ecd - %', coalesce(p_text, '<empty>');
      WHEN cLevel_Dbg THEN
         RAISE DEBUG   'ecd - %', coalesce(p_text, '<empty>');
      WHEN cLevel_Inf THEN
         RAISE NOTICE  'ecd - %', coalesce(p_text, '<empty>');
      WHEN cLevel_Wrn THEN
         RAISE WARNING 'ecd - %', coalesce(p_text, '<empty>');
      WHEN cLevel_Err THEN
         RAISE WARNING 'ecd - %', coalesce(p_text, '<empty>');
      ELSE
         RAISE DEBUG   'ecd - %', coalesce(p_text, '<empty>');
   END CASE;
END;
$procedure$


/* */
CREATE PROCEDURE trc(
   p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL log(cLevel_Trc, p_text);
END;
$procedure$


/* */
CREATE PROCEDURE dbg(
   p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL log(cLevel_Dbg, p_text);
END;
$procedure$


/* */
CREATE PROCEDURE inf(
   p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL log(cLevel_Inf, p_text);
END;
$procedure$


/* */
CREATE PROCEDURE wrn(
   p_text varchar
)
AS
$procedure$
BEGIN
   CALL log(cLevel_Wrn, p_text);
END;
$procedure$


/* */
CREATE PROCEDURE err(
   p_text varchar
)
AS
$procedure$
BEGIN
   CALL log(cLevel_Err, p_text);
END;
$procedure$

;