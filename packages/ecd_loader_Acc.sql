CREATE OR REPLACE PACKAGE ecd_loader_Acc
CREATE FUNCTION __init__()
   RETURNS void
AS
$init$
#export off
DECLARE
   cVersion CONSTANT varchar(100) := '$id: {0.1.0} {10.04.2026} Lora$';

   RET_OK   CONSTANT int4 := 0;
   RET_FAIL CONSTANT int4 := -1;
BEGIN
   RAISE DEBUG 'Package "ecd_loader_acc" - % - initialized', cVersion;
END;
$init$


/* Версия */
CREATE FUNCTION get_Version( )
   RETURNS varchar
AS
$function$
BEGIN
   RETURN cVersion;
END;
$function$


/* Проверка существования счета */
CREATE FUNCTION check_Acc (
   IN p_acc varchar
)
   RETURNS boolean
AS
$function$
BEGIN

   IF p_acc IS NULL THEN
      RETURN FALSE;
   END IF;

   IF EXISTS (
      SELECT 1
        FROM acc a
       WHERE a.cAccAcc = p_acc
   ) THEN
      RETURN TRUE;
   END IF;

   CALL ecd_loader_Ret.put_Warn( 'cda.acc', 'Счет "' || p_acc || '" не обработан! Т.к. отсутствует в справочнике счетов XXI' );

   RETURN FALSE;

END;
$function$


/* Установить текущий счет */
CREATE PROCEDURE set_Current_Acc(
   IN p_agr_Id     numeric,
   IN p_acc        varchar,
   IN p_params_Xml xml
)
AS
$procedure$
DECLARE
   l_acc        varchar := p_acc;
   l_error_Info varchar;
   l_ret        boolean;
   r            record;
BEGIN

   IF 1 = 0
      AND ecd_loader_Xml.get_Parameter(p_params_Xml, 'replace_account', '0') = '1'
   THEN
      SELECT pl_ca.cAccAcc,
             pl_ca.cAccCur
        INTO r
        FROM pl_ca
        JOIN pl_pla_cd
          ON pl_pla_cd.iPlaAgrId = pl_ca.iPlaAgrId
       WHERE pl_pla_cd.nCdaAgrId = p_agr_Id
         AND pl_ca.iPlScaType IN (-1, 14)
       ORDER BY pl_ca.iPlScaType
       LIMIT 1;

      IF r.cAccAcc IS NULL THEN

         CALL CDCes.Create_Acc(
            ret     => l_ret,
            agrId   => p_agr_Id,
            bs2     => 42309,
            newAcc  => r.cAccAcc,
            retInfo => l_error_Info
         );

         IF NOT l_ret THEN
            CALL ecd_loader_Ret.put_Error(
               'cda.acc',
               'Ошибка заведения текущего счета: ' || coalesce(l_error_Info, '<NULL>')
            );
            RETURN;
         END IF;
      END IF;

      l_acc := coalesce(r.cAccAcc, p_acc);
   END IF;

   UPDATE cda
      SET iCdaCurrentType = 0,
          cCdaCurrentAcc  = l_acc
    WHERE 
          nCdaAgrID       = p_agr_Id;

END;
$procedure$


/* Вставить запись в cd_acc */
CREATE PROCEDURE insert_Cd_Acc (
   IN p_agr_Id    numeric,
   IN p_type      numeric,
   IN p_acc       varchar,
   IN p_sub_Type  numeric
)
AS
$procedure$
   #package
BEGIN

   INSERT INTO cd_acc( nCdAccAgrId, iCdAccType, cCdAccAcc, cCdAccCur, iCdAccSubType )
   SELECT
      p_agr_Id, p_type, p_acc, CDTerms.Get_ACCcur(p_acc), coalesce(p_sub_Type, 0)
    WHERE NOT EXISTS (
      SELECT 1
        FROM cd_acc a
       WHERE 
             a.nCdAccAgrId = p_agr_Id
         AND a.cCdAccAcc   = p_acc
   );

END;
$procedure$


/* Вставить запись в cda_acc */
CREATE PROCEDURE insert_Cda_Acc(
   IN p_agr_Id    numeric,
   IN p_type      numeric,
   IN p_acc       varchar,
   IN p_sub_Type  numeric
)
AS
$procedure$
BEGIN

   INSERT INTO cda_acc(
      nAddAgrId,
      nAddType,
      cAddAcc,
      cAddCurIso,
      iAddSubType,
      iAddOrder
   )
   SELECT
      p_agr_Id,
      p_type,
      p_acc,
      CDTerms.Get_ACCcur(p_acc),
      p_sub_Type,
      coalesce(
         (
            SELECT max(a.iAddOrder) + 1
              FROM cda_acc a
             WHERE a.nAddAgrId = p_agr_Id
               AND a.nAddType  = p_type
         ),
         1
      )
    WHERE NOT EXISTS (
      SELECT 1
        FROM cda_acc a
       WHERE a.nAddAgrId = p_agr_Id
         AND a.cAddAcc   = p_acc
   );

END;
$procedure$

/* Обработка счетов обеспечения */
CREATE PROCEDURE handle_Czo_Acc(
   IN p_agr_Id      numeric,
   IN p_type        numeric,
   IN p_acc         varchar,
   IN p_acc_Doc_Num varchar
)
AS
$procedure$
DECLARE
   l_czo_Id numeric;
BEGIN

   IF p_acc_Doc_Num IS NULL THEN

      CALL ecd_loader_Ret.put_Warn( 'czo.acc', 'Счет "' || p_acc || '" не обработан! Для счета не задан "acc_doc_num" - номер учетного док-та обеспечения.' );
      RETURN;

   END IF;

   SELECT v.iCzoId
          INTO l_czo_Id
     FROM v_czo v
    WHERE 
         v.cCdhAtribut = p_acc_Doc_Num AND v.nCdaAgrId = p_agr_Id;

   IF NOT FOUND THEN

      CALL ecd_loader_Ret.put_Warn( 'czo.acc','Счет "' || p_acc || '" не обработан! Для acc_doc_num = "' || p_acc_Doc_Num || '" невозможно определить Id записи обеспечения!');
      RETURN;

   END IF;

   IF p_type IN (24, 52) THEN

      UPDATE czo
         SET cCzoSchet = p_acc
       WHERE iCzo      = l_czo_Id;

   ELSIF p_type = 111 THEN

      UPDATE czo
         SET cCzoSecurAcc = p_acc,
             cCzoSecurCur = CDTerms.Get_ACCcur(p_acc)
       WHERE iCzo         = l_czo_Id;

   END IF;

END;
$procedure$


/* Обработка комиссионных счетов */
CREATE PROCEDURE handle_Com_Acc (
   IN p_agr_Id    numeric,
   IN p_type      numeric,
   IN p_acc       varchar,
   IN p_sub_Type  numeric
)
AS
$procedure$
DECLARE
   l_sb_Type numeric;
BEGIN

   SELECT a.cCdiNew
     INTO l_sb_Type
     FROM cd_impdecode a
    WHERE a.cCdiMpType = 'ICMFID'
      AND a.cCdiOld    = p_sub_Type;

   IF NOT FOUND THEN
      l_sb_Type := p_sub_Type;
   END IF;

   BEGIN
      INSERT INTO cd_acc( nCdAccAgrId, iCdAccType, cCdAccAcc, cCdAccCur, iCdAccSubType )
      VALUES ( p_agr_Id, p_type, p_acc, CDTerms.Get_ACCcur(p_acc), coalesce(l_sb_Type, 0) );
   EXCEPTION
      WHEN unique_violation THEN
         UPDATE cd_acc a
            SET cCdAccAcc     = p_acc,
                cCdAccCur     = CDTerms.Get_ACCcur(p_acc),
                iCdAccSubType = coalesce(l_sb_Type, 0)
          WHERE a.nCdAccAgrId = p_agr_Id
            AND a.iCdAccType  = p_type;
   END;

END;
$procedure$

/* Вызов handler-а счетов */
CREATE PROCEDURE run_Acc_Handler (
   IN   p_ctx         ecd_loader_Types.Сtx_t,
   IN   p_agr_Id      numeric,
   OUT  p_result_Code int4,
   OUT  p_result_Info varchar
)
AS
$procedure$
BEGIN

   p_result_Code := RET_OK;
   p_result_Info := NULL;

   IF NOT coalesce(p_ctx.run_ffv, FALSE) THEN
      RETURN;
   END IF;

   CALL ecd_loader_Dep.run_Acc_Handler(
      p_agr_Id,
      p_result_Code,
      p_result_Info
   );

END;
$procedure$

/* Загрузка списка счетов */
CREATE PROCEDURE load_Acc_List(
   IN     p_ctx         ecd_loader_types.ctx_t,
   IN     p_agr_Id      numeric,
   IN     p_xml         xml,
   OUT    p_result_Code int4,
   OUT    p_result_Info varchar
)
AS
$procedure$
DECLARE
   l_count         int4 := 0;
   l_handler_Code  int4;
   l_handler_Info  varchar;
   r               record;
BEGIN

   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   CALL ecd_loader_Log.dbg(
      'ecd_loader_Acc.load_Acc_List: agr_Id=' || coalesce(p_agr_Id::varchar, '<NULL>')
   );

   -- Есть ли счета в переданном XML
   IF NOT ecd_loader_Xml.exists_Node (
      p_xml,
      '//CDA/CDA_ACC/item'
   ) THEN
      p_result_Code := RET_OK;
      RETURN;
   END IF;

   FOR r IN
      SELECT *
        FROM XMLTABLE(
           '//CDA/CDA_ACC/item'
           PASSING p_xml
           COLUMNS
              iType      numeric      PATH 'type',
              cAcc       varchar(50)  PATH 'acc',
              iSubType   numeric      PATH 'sub_type',
              cAccDocNum varchar(100) PATH 'acc_doc_num'
        )
   LOOP

      IF r.cAcc IS NULL THEN
         CONTINUE;
      END IF;

      IF NOT check_Acc(r.cAcc) THEN
         CONTINUE;
      END IF;

      CASE r.iType

         WHEN 2 THEN
            CALL set_Current_Acc(
               p_agr_Id,
               r.cAcc,
               p_ctx.params_xml
            );

         WHEN 5 THEN
            UPDATE cda
               SET cCdaPrsrAcc = r.cAcc,
                   cCdaPrsrCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID   = p_agr_Id;

         WHEN 6 THEN
            UPDATE cda
               SET cCdaPrsrPcAcc = r.cAcc,
                   cCdaPrsrPcCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID     = p_agr_Id;

         WHEN 7 THEN
            UPDATE cda
               SET cCdaRiskAcc = r.cAcc,
                   cCdaRiskCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID   = p_agr_Id;

         WHEN 10 THEN
            UPDATE cda
               SET cCdaAccumAcc = r.cAcc,
                   cCdaAccumCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID    = p_agr_Id;

         WHEN 11 THEN
            UPDATE cda
               SET cCdaFuturAcc = r.cAcc,
                   cCdaFuturCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID    = p_agr_Id;

         WHEN 13 THEN
            UPDATE cda
               SET cCdaPrsrPc2Acc = r.cAcc,
                   cCdaPrsrPc2Cur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID      = p_agr_Id;

         WHEN 20 THEN
            UPDATE cda
               SET cCdaRiskOAcc = r.cAcc,
                   cCdaRiskOCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID    = p_agr_Id;

         WHEN 22 THEN
            UPDATE cda
               SET cCdaNoLimAcc = r.cAcc,
                   cCdaNoLimCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID    = p_agr_Id;

         WHEN 23 THEN
            UPDATE cda
               SET cCdaAccum2Acc = r.cAcc,
                   cCdaAccum2Cur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID     = p_agr_Id;

         WHEN 25 THEN
            UPDATE cda
               SET cCdaAccumFAcc = r.cAcc,
                   cCdaAccumFCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID     = p_agr_Id;

         WHEN 26 THEN
            UPDATE cda
               SET cCdaAccumFpAcc = r.cAcc,
                   cCdaAccumFpCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID      = p_agr_Id;

         WHEN 27 THEN
            UPDATE cda
               SET cCdaAccumFNbAcc = r.cAcc,
                   cCdaAccumFNbCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID       = p_agr_Id;

         WHEN 28 THEN
            UPDATE cda
               SET cCdaAccumFpNbAcc = r.cAcc,
                   cCdaAccumFpNbCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID        = p_agr_Id;

         WHEN 29 THEN
            UPDATE cda
               SET cCdaRisk137Acc = r.cAcc,
                   cCdaRisk137Cur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID      = p_agr_Id;

         WHEN 100 THEN
            UPDATE cda
               SET iCdaCurrentType = 1,
                   cCdaCurrentAcc  = r.cAcc
             WHERE nCdaAgrID       = p_agr_Id;

         WHEN 101 THEN
            UPDATE cda
               SET cCdaAccumOAcc = r.cAcc,
                   cCdaAccumOCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID     = p_agr_Id;

         WHEN 106 THEN
            UPDATE cda
               SET cCdaPrpcOAcc = r.cAcc,
                   cCdaPrpcOCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID    = p_agr_Id;

         WHEN 110 THEN
            UPDATE cda
               SET cCdaFuturOAcc = r.cAcc,
                   cCdaFuturOCur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID     = p_agr_Id;

         WHEN 113 THEN
            UPDATE cda
               SET cCdaPrpcO2Acc = r.cAcc,
                   cCdaPrpcO2Cur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID     = p_agr_Id;

         WHEN 230 THEN
            UPDATE cda
               SET cCdaAccumO2Acc = r.cAcc,
                   cCdaAccumO2Cur = CDTerms.Get_ACCcur(r.cAcc)
             WHERE nCdaAgrID      = p_agr_Id;

         WHEN 24 THEN
            CALL handle_Czo_Acc(
               p_agr_Id,
               r.iType,
               r.cAcc,
               r.cAccDocNum
            );

         WHEN 52 THEN
            CALL handle_Czo_Acc(
               p_agr_Id,
               r.iType,
               r.cAcc,
               r.cAccDocNum
            );

         WHEN 111 THEN
            CALL handle_Czo_Acc(
               p_agr_Id,
               r.iType,
               r.cAcc,
               r.cAccDocNum
            );

         WHEN 2000 THEN
            CALL insert_Cda_Acc(
               p_agr_Id,
               2,
               r.cAcc,
               r.iSubType
            );

         WHEN 2001 THEN
            INSERT INTO cda_acc_out(
               nAddAgrId,
               iAddTypeOut,
               nAddType,
               cAddAcc,
               cAddCurIso
            )
            VALUES (
               p_agr_Id,
               1,
               2,
               r.cAcc,
               CDTerms.Get_ACCcur(r.cAcc)
            );

         ELSE
            IF r.iType IN (40, 41, 45, 57, 59, 66, 69, 70, 71, 85, 86, 145, 207) THEN
               CALL handle_Com_Acc(
                  p_agr_Id,
                  r.iType,
                  r.cAcc,
                  r.iSubType
               );
            ELSE
               CALL insert_Cd_Acc(
                  p_agr_Id,
                  r.iType,
                  r.cAcc,
                  r.iSubType
               );
            END IF;

      END CASE;

      l_count := l_count + 1;

   END LOOP;


   /* Вызов ФПЗ */
   CALL run_Acc_Handler(
      p_ctx,
      p_agr_Id,
      l_handler_Code,
      l_handler_Info
   );

   IF l_handler_Code <> RET_OK THEN
      p_result_Code := RET_FAIL;
      p_result_Info := l_handler_Info;
      RETURN;
   END IF;

   p_result_Code := RET_OK;
   p_result_Info := NULL;

EXCEPTION
   WHEN OTHERS THEN
      p_result_Code := RET_FAIL;
      p_result_Info := SQLERRM;
END;
$procedure$

--end_Of_Package
;