CREATE OR REPLACE PACKAGE ecd_loader_Agr
   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   #export off
   DECLARE
      -- Пакет загрузчика для работы с данными загружаемого договора
      cVersion CONSTANT varchar(100) := '$id: {0.1.0} {10.04.2026} Lora$';

      RET_OK   CONSTANT int4 := 0;
      RET_FAIL CONSTANT int4 := -1;

   BEGIN
      RAISE DEBUG 'Package "ecd_loader_agr" - % - initialized', cVersion;
   END;
   $init$


/* */
CREATE FUNCTION get_Version( )
   RETURNS varchar
AS
$function$
   #package
BEGIN
   RETURN cVersion;
END;
$function$


/* Разбор XML договора в Agr_t */
CREATE FUNCTION parse_Agr (
   IN p_ctx     ECD_loader_Types.Ctx_t,
   IN p_cus_Id  numeric
)
   RETURNS 
      ECD_loader_Types.Agr_t
AS
$function$
   #package
   #private
DECLARE
   l_agr ECD_loader_Types.Agr_t;
BEGIN

   l_agr.cus_id          := p_cus_Id;
   -- ID договора, может приходить из вне
   l_agr.agr_id          := ecd_loader_Xml.get_Numeric_Val(p_ctx.input_xml, '//CDA/@NCDAAGRID');
   -- ЮР-номер
   l_agr.ext_num         := ecd_loader_Xml.get_String_Val (p_ctx.input_xml, '//CDA/identifier/text()');
   -- Внешний идентификатор, из внешней системы
   l_agr.ext_id          := ecd_loader_Xml.get_String_Val (p_ctx.input_xml, '//CDA/external_id/text()');

   l_agr.mda_Id          := ecd_loader_Xml.get_Numeric_Val(p_ctx.input_xml, '//CDA/CDA_MDA/@IMD2NUM');
   l_agr.mak_external_id := ecd_loader_Xml.get_String_Val (p_ctx.input_xml, '//CDA/CDA_MDA/identifier/text()');

   l_agr.dt_buy          := ecd_loader_Xml.get_Date_Val   (p_ctx.input_xml, '//CDA/CDA_DATE/item[@id="cession_buy"]/text()');
   l_agr.dt_end          := ecd_loader_Xml.get_Date_Val   (p_ctx.input_xml, '//CDA/CDA_DATE/item[@id="end"]/text()');
   l_agr.d_sign          := ecd_loader_Xml.get_Date_Val   (p_ctx.input_xml, '//CDA/CDA_DATE/item[@id="accept"]/text()');
   l_agr.d_first_pay_a   := ecd_loader_Xml.get_Date_Val   (p_ctx.input_xml, '//CDA/CDA_DATE/item[@id="cession_nextPayment"]/text()');
   l_agr.d_original      := ecd_loader_Xml.get_Date_Val   (p_ctx.input_xml, '//CDA/CDA_DATE/item[@id="original_date"]/text()');
   l_agr.d_original_end  := ecd_loader_Xml.get_Date_Val   (p_ctx.input_xml, '//CDA/CDA_DATE/item[@id="original_date_end"]/text()');
   l_agr.d_date_of_issue := ecd_loader_Xml.get_Date_Val   (p_ctx.input_xml, '//CDA/CDA_DATE/item[@id="date_of_issue"]/text()');

   l_agr.total_sum       := ecd_loader_Xml.get_Money_Val  (p_ctx.input_xml, '//CDA/CDA_SUM/item[@id="agr"]/text()');
   l_agr.amount_agr      := ecd_loader_Xml.get_Money_Val  (p_ctx.input_xml, '//CDA/CDA_PART/item[@part="1"]/CDA_SUM/item[@id="debt"]/text()');
   l_agr.pay_sum         := ecd_loader_Xml.get_Money_Val  (p_ctx.input_xml, '//CDA/CDA_SUM/item[@id="monthly"]/text()');
   l_agr.premium_sum     := ecd_loader_Xml.get_Money_Val  (p_ctx.input_xml, '//CDA/CDA_SUM/item[@id="premium"]/text()');

   l_agr.ext_percent     := ecd_loader_Xml.get_Percent_Val(p_ctx.input_xml, '//CDA/CDA_PART/item[@part="1"]/interest_rate/text()');
   l_agr.psk             := ecd_loader_Xml.get_Percent_Val(p_ctx.input_xml, '//CDA/CDA_COEFF/item[@id="psk"]/text()');

   l_agr.purchase_type   := ecd_loader_Xml.get_Numeric_Val(p_ctx.input_xml, '//CDA/purchase_type/text()');
   l_agr.coeff_discount  := ecd_loader_Xml.get_Percent_Val(p_ctx.input_xml, '//CDA/CDA_COEFF/item[@id="discount"]/text()');
   l_agr.initial_id      := ecd_loader_Xml.get_String_Val (p_ctx.input_xml, '//CDA/initial_id/text()');

   l_agr.nTime_y         := coalesce(ecd_loader_Xml.get_Numeric_Val(p_ctx.input_xml, '//CDA/CDA_PERIOD/years/text()'),  0)::int4;
   l_agr.nTime_m         := coalesce(ecd_loader_Xml.get_Numeric_Val(p_ctx.input_xml, '//CDA/CDA_PERIOD/months/text()'), 0)::int4;
   l_agr.nTime_d         := coalesce(ecd_loader_Xml.get_Numeric_Val(p_ctx.input_xml, '//CDA/CDA_PERIOD/days/text()'),   0)::int4;

   l_agr.purpose_id      := ecd_loader_Xml.get_Numeric_Val(p_ctx.input_xml, '//CDA/CDA_PURPOSE/@ICDAPURPOSE');
   l_agr.purpose_num     := ecd_loader_Xml.get_String_Val (p_ctx.input_xml, '//CDA/CDA_PURPOSE/identifier/text()');
   -- ID портфеля покупки/продажи
   l_agr.pfl_Id          := ecd_loader_Xml.get_Numeric_Val(p_ctx.input_xml, '//CDA/CDA_PFL/@ICDSALEID');
   -- номер портфеля
   l_agr.pfl_Num         := ecd_loader_Xml.get_String_Val (p_ctx.input_xml, '//CDA/CDA_PFL/identifier/text()');
   -- фин параметры
   l_agr.fin_res         := ecd_loader_Xml.get_String_Val (p_ctx.input_xml, '//CDA/fin_res/text()');
   l_agr.owd             := ecd_loader_Xml.get_String_Val (p_ctx.input_xml, '//CDA/owd/text()');
   l_agr.uuid            := ecd_loader_Xml.get_String_Val (p_ctx.input_xml, '//CDA/uuid/text()');

   l_agr.annuity_day     := ecd_loader_Xml.get_Numeric_Val(p_ctx.input_xml, '//CDA/CDA_ANNUITY/day/text()')::int4;
   l_agr.icdhstdid       := ecd_loader_Xml.get_Numeric_Val(p_ctx.input_xml, '//CDA/ICDHSTDID/text()');
   l_agr.msfo_std        := ecd_loader_Xml.get_String_Val (p_ctx.input_xml, '//CDA/msfo_std/text()');
   l_agr.msfo_seg        := ecd_loader_Xml.get_String_Val (p_ctx.input_xml, '//CDA/msfo_seg/text()');

   l_agr.cda_note        := ecd_loader_Xml.get_String_Val (p_ctx.input_xml, '//CDA/cdaNote/text()');

   l_agr.optional_attrs  := ecd_loader_Xml.get_Xml_Val    (p_ctx.input_xml, '//CDA/OPTIONAL_ATTRS');
   l_agr.parts_xml       := ecd_loader_Xml.get_Xml_Val    (p_ctx.input_xml, '//CDA/CDA_PART/item');
   l_agr.jnt_cus_xml     := ecd_loader_Xml.get_Xml_Val    (p_ctx.input_xml, '//CDA/CDA_JNT_CUS/item');

   RETURN l_agr;

END;
$function$

/*
-- Проверка наличия процентной ставки,
-- Если на договоре отсутствует, то пытаемся получить из истории
out_put( 'check INTRATE ...' );

IF nvl( l_agrData.extProcent, 0 ) = 0 THEN

   DECLARE

      CURSOR c_get_Last_IntRate
      IS
         SELECT y.PCDHPVAL FROM (
            SELECT
                TO_NUMBER( REPLACE( REPLACE( x.PCDHPVAL_S, ' ' ), ',', '.' ), FORMAT_PERCENT ) PCDHPVAL,
                TO_DATE  ( dcdhdate_s, 'YYYY-MM-DD' ) DCDHDATE
            FROM
              XMLTABLE( '//CDA_PART/item[@part="1"]/CDA_HTERM/item[term="INTRATE"]'
                   PASSING l_xData
              COLUMNS
                   PCDHPVAL_S VARCHAR2(30) path 'percent_value',
                   dcdhdate_s VARCHAR2(30) path 'date'
            ) x
         ) y
         ORDER BY y.DCDHDATE DESC;

   BEGIN
      -- /XXI_DATA_PACK/CDA/CDA_PART/item[@part='1']/CDA_HTERM/item[term='INTRATE']/percent_value
      OPEN c_get_Last_IntRate;
         FETCH c_get_Last_IntRate
            INTO l_agrData.extProcent;
               CLOSE c_get_Last_IntRate;

      IF NVL( l_agrData.extProcent, 0 ) = 0 THEN
         RAISE NO_DATA_FOUND;
      END IF;

   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         out_put('NO INTRATE - % ставка не задана, будет взята с макета');
         addReturnInfo( 'cda', '% ставка не задана, будет взята с макета' );
   END;
END IF;
*/


/* Проверить/дополнить процентную ставку */
CREATE PROCEDURE prepare_Rate (
   IN     p_ctx ecd_loader_types.ctx_t,
   IN OUT p_agr ecd_loader_types.agr_t
)
AS
$procedure$
   #package
BEGIN

   IF coalesce( p_agr.ext_percent, 0 ) <> 0 THEN
      RETURN;
   END IF;

   SELECT z.pcdhpval
     INTO p_agr.ext_percent
     FROM (
        SELECT
           ecd_loader_xml.to_percent(x.pcdhpval_s) AS pcdhpval,
           to_date(x.dcdhdate_s, 'YYYY-MM-DD')     AS dcdhdate
          FROM XMLTABLE(
             '//CDA_PART/item[@part="1"]/CDA_HTERM/item[term="INTRATE"]'
             PASSING p_ctx.input_Xml
             COLUMNS
                pcdhpval_s varchar(30) PATH 'percent_value',
                dcdhdate_s varchar(30) PATH 'date'
          ) x
        WHERE x.pcdhpval_s IS NOT NULL
     ) z
    ORDER BY z.dcdhdate DESC
    LIMIT 1;

   IF coalesce(p_agr.ext_percent, 0) = 0 THEN
      CALL ecd_loader_ret.put_Warn( 'cda', '% ставка не задана, будет взята с макета' );
   END IF;

END;
$procedure$

/* Определить макет */
CREATE PROCEDURE resolve_Mda (
   IN     p_ctx ECD_loader_Types.ctx_t,
   IN OUT p_agr ECD_loader_Types.agr_t
)
AS
$procedure$
   #package
BEGIN

   IF p_agr.mda_id IS NULL THEN
      p_agr.mda_id := ECD_loader_Map.get_Internal_Id( p_ctx.provider_id, 4::int4, p_agr.mak_external_Id )::numeric;
   END IF;

   IF p_agr.mda_id IS NULL THEN

      CALL ECD_loader_Err.raise_Config_Error (
         'MDA_NOT_FOUND',
         'Невозможно определить ID макета XXI по коду "' || coalesce(p_agr.mak_external_id, '<NULL>') || '" из внешних данных. Проверьте настройки макетов договоров для провайдера ' || coalesce( p_ctx.provider_id, '<NULL>')
      );

   END IF;

   CALL ECD_loader_Ret.put_Info( 'cda', 'Макет для договора: ' || p_agr.mda_Id::varchar );

END;
$procedure$


/* Определить / проверить ID договора */
CREATE PROCEDURE resolve_Agr_Id (
   IN     p_ctx ECD_loader_Types.ctx_t,
   IN OUT p_agr ECD_loader_Types.agr_t
)
AS
$procedure$
   #package
DECLARE
   l_tmp_Agr_Id numeric;
BEGIN

   IF p_agr.agr_Id IS NULL THEN
      p_agr.agr_Id := CDTerms.New_ID_to_MAK( p_agr.mda_id );
   ELSE
      l_tmp_Agr_Id := ECD_loader_Map.get_Cda_Id_By_Ext_Id( p_agr.agr_id::varchar, 3 );

      IF l_tmp_Agr_Id IS NOT NULL THEN

         CALL ECD_loader_Err.raise_Data_Error (
            'AGR_ID_ALREADY_EXISTS',
            'Договор с идентификатором ' || p_agr.agr_id::varchar || ' уже существует.'
         );

      END IF;

   END IF;

END;
$procedure$


/* 
   Проверить ограничения по договору:
   - обратный выкуп
   - дублирование Id 
*/
CREATE PROCEDURE validate_Agr (
   IN p_ctx ECD_loader_Types.ctx_t,
   IN p_agr ECD_loader_Types.agr_t
)
AS
$procedure$
   #package
DECLARE
   l_tmp_Agr_Id numeric;
   l_dummy      numeric;
BEGIN

   IF p_agr.initial_Id IS NOT NULL THEN

      IF ECD_loader_Map.get_Cda_Id_By_Ext_Id(p_agr.initial_id, 3) IS NULL THEN

         CALL ECD_loader_Err.raise_Data_Error(
            'INITIAL_ID_NOT_FOUND',
            'Договор для обратного выкупа с исходным идентификатором '
            || p_agr.initial_id || ' не найден.'
         );

      END IF;

      IF ECD_loader_Map.get_Cda_Id_By_Ext_Id(p_agr.initial_id, 4) IS NOT NULL THEN

         CALL ECD_loader_Err.raise_Data_Error(
            'INITIAL_ID_ALREADY_USED',
            'Для договора с ID ' || p_agr.initial_id || ' уже был загружен договор обратного выкупа'
         );

      END IF;

      BEGIN
         SELECT 1
           INTO STRICT l_dummy
           FROM cda a
          WHERE a.nCdaAgrID = p_agr.initial_id::numeric
            AND coalesce( a.cCdaAgrMnt, ' ') = coalesce( p_agr.ext_Num, ' ' );
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            CALL ECD_loader_Err.raise_Data_Error(
               'INITIAL_ID_JUR_NOT_EQ',
               'Для договора обратного выкупа необходимо чтобы ID и Юр.номер совпадали с теми которые в БД.'
            );
      END;

   ELSE

      IF NOT p_ctx.ignore_check_jur_n THEN

         l_tmp_Agr_Id := ECD_loader_Map.get_Cda_Id_By_Ext_Id( p_agr.ext_num, 1 );

         IF l_tmp_Agr_Id IS NOT NULL THEN

            CALL ECD_loader_Err.raise_Data_Error(
               'AGR_JUR_ALREADY_EXISTS',
               'Договор с юр. номером ' || p_agr.ext_num || ' уже загружен. (cda.nCdaAgrID = ' || l_tmp_Agr_Id::varchar || ')'
            );
         END IF;

      END IF;

   END IF;

END;
$procedure$


/* Определить тип приобретения / портфель */
CREATE PROCEDURE resolve_Purchase (
   IN     p_ctx ECD_loader_Types.ctx_t,
   IN OUT p_agr ECD_loader_Types.agr_t
)
AS
$procedure$
   #package
DECLARE
   l_type  numeric;
   l_value numeric;
BEGIN

   IF p_agr.pfl_id IS NOT NULL OR p_agr.pfl_num IS NOT NULL THEN

      p_agr.pfl_id := ECD_loader_Map.get_CdSale_Id (
         p_agr.agr_id,
         coalesce( p_agr.pfl_id::varchar, p_agr.pfl_num),
         CASE WHEN p_agr.pfl_id IS NULL THEN 2 ELSE 1 END
      );

      IF p_agr.pfl_id IS NULL THEN
         
         CALL ECD_loader_Err.raise_Data_Error (
            'PFL_NOT_FOUND',
            'Не возможно получить идентификатор портфеля по переданным параметрам'
         );

      END IF;

      IF p_agr.purchase_type IS NULL THEN

         CALL ECD_loader_Map.get_Purchase_Pfl (
            p_agr.pfl_id,
            l_type,
            l_value
         );

         p_agr.purchase_type := l_type;

         IF p_agr.purchase_type = 1 THEN
            p_agr.coeff_discount := l_value;
         ELSIF p_agr.purchase_type = 2 THEN
            p_agr.premium_sum := l_value;
         END IF;
      END IF;

   END IF;

END;
$procedure$


/* Создать договор */
CREATE PROCEDURE create_Agr (
   IN     p_ctx ECD_loader_Types.ctx_t,
   IN OUT p_agr ECD_loader_Types.agr_t
)
AS
$procedure$
DECLARE
   l_result_Code int4;
   l_result_Info varchar;
BEGIN

   IF p_agr.fin_res IS NULL THEN
      p_agr.fin_res := p_ctx.fin_res_sum;
   END IF;

   CALL ecd_loader_Dep.new_Ces (
      p_agr,
      l_result_Code,
      l_result_Info
   );

   IF l_result_Code <> RET_OK THEN
      CALL ECD_loader_Err.raise_Data_Error(
         'NEW_CES_FAILED',
         'CDCes.New_Ces: ' || coalesce(l_result_Info, '<NULL>')
      );
   END IF;

END;
$procedure$


/* Создать связь с портфелем */
CREATE PROCEDURE link_To_Pfl (
   IN p_agr ECD_loader_Types.agr_t
)
AS
$procedure$
   #package
BEGIN

   IF p_agr.pfl_id IS NULL THEN
      RETURN;
   END IF;

   INSERT INTO cda_link_cdsale(
      nCdaAgrId,
      iCdSaleId
   )
   SELECT p_agr.agr_id,
          p_agr.pfl_id
    WHERE NOT EXISTS (
      SELECT 1
        FROM cda_link_cdsale b
       WHERE b.nCdaAgrId = p_agr.agr_id
         AND b.iCdSaleId = p_agr.pfl_id
   );

END;
$procedure$


/* Сохранить UUID */
CREATE PROCEDURE save_Uuid (
   IN p_agr ECD_loader_Types.Agr_t
)
AS
$procedure$
   #package
DECLARE
   l_result_Code int4;
   l_result_Info varchar;
BEGIN

   IF p_agr.uuid IS NULL THEN
      RETURN;
   END IF;

   CALL ECD_loader_Dep.merge_Cb_Uuid (
      p_agr.agr_id,
      p_agr.uuid,
      l_result_Code,
      l_result_Info
   );

   IF l_result_Code <> RET_OK THEN
      CALL ECD_loader_Ret.put_Warn (
         'cda',
         'Ошибка при сохранении УИД: ' || coalesce(l_result_Info, '<NULL>'),
         p_agr.uuid,
         p_agr.agr_id::varchar
      );
   END IF;

END;
$procedure$


/* Сохранить meta в cda2 */
CREATE PROCEDURE save_Meta(
   IN p_agr ECD_loader_Types.agr_t
)
AS
$procedure$
   #package
BEGIN

   UPDATE cda2
      SET cCda2ExtID       = p_agr.ext_id,
          cCda2PrimID      = p_agr.initial_id,
          dCda2AgrFbDate   = p_agr.d_original,
          dCda2AgrFEndDate = p_agr.d_original_end,
          cCda2Comm        = p_agr.cda_note,
          nCda2TpFlg       = 1
    WHERE nCda2AgrID       = p_agr.agr_id;

END;
$procedure$


/* Сохранить цель договора */
CREATE PROCEDURE save_Purpose(
   IN     p_ctx ECD_loader_Types.ctx_t,
   IN OUT p_agr ECD_loader_Types.agr_t
)
AS
$procedure$
   #package
BEGIN

   IF p_agr.purpose_id IS NULL AND p_agr.purpose_num IS NOT NULL 
   THEN
      p_agr.purpose_id := ECD_loader_Map.get_Internal_Id( p_ctx.provider_id, 6, p_agr.purpose_num)::numeric;
   END IF;

   IF p_agr.purpose_id IS NULL THEN
      RETURN;
   END IF;

   UPDATE cda
      SET iCdaPurpose = p_agr.purpose_id
    WHERE nCdaAgrID   = p_agr.agr_id;

   CALL ecd_loader_Dep.update_History(
      p_agr.agr_id,
      1,
      'PURPOSE',
      p_agr.dt_buy,
      NULL,
      NULL,
      NULL,
      p_agr.purpose_id
   );

END;
$procedure$


/* Сохранить IFRS */
CREATE PROCEDURE save_Ifrs(
   IN     p_ctx ECD_loader_Types.Ctx_t,
   IN OUT p_agr ECD_loader_Types.Agr_t
)
AS
$procedure$
   #package
DECLARE
   l_stage_Id    numeric;
   l_result_Code int4;
   l_result_Info varchar;
BEGIN

   IF p_agr.icdhstdid IS NOT NULL THEN
      UPDATE cdifrs_cdh
         SET iCdhStdId = p_agr.icdhstdid
       WHERE nCdhAgrId = p_agr.agr_id;
   END IF;

   IF p_agr.msfo_std IS NOT NULL THEN
      l_stage_Id := ECD_loader_Map.get_Internal_Id(
         p_ctx.provider_id,
         10,
         p_agr.msfo_std
      )::numeric;

      CALL ecd_loader_Dep.set_Ifrs_Stage(
         p_agr.agr_id,
         p_agr.cus_id,
         l_stage_Id,
         l_result_Code,
         l_result_Info
      );

      IF l_result_Code <> RET_OK THEN
         CALL ECD_loader_Ret.put_Warn(
            'cda',
            'Ошибка установки стадии МСФО: ' || coalesce(l_result_Info, '<NULL>'),
            p_agr.msfo_std,
            p_agr.agr_id::varchar
         );
      END IF;
   END IF;

   IF p_agr.msfo_seg IS NOT NULL THEN
      CALL ecd_loader_Dep.update_History (
         p_agr.agr_id,
         1,
         'IFRS_SG',
         p_agr.dt_buy,
         NULL,
         NULL,
         NULL,
         ECD_loader_Map.get_Internal_Id( p_ctx.provider_id, 11, p_agr.msfo_seg )::numeric
      );
   END IF;

END;
$procedure$


/* Сохранить ПСК */
CREATE PROCEDURE save_Psk(
   IN p_agr ECD_loader_Types.agr_t
)
AS
$procedure$
   #package
BEGIN
   IF p_agr.psk IS NOT NULL THEN
      CALL ECD_loader_Dep.update_History( p_agr.agr_id, NULL, 'FULLRATE', p_agr.dt_buy, NULL, NULL, p_agr.psk, NULL );
   END IF;
END;
$procedure$


/* Создать части договора */
CREATE PROCEDURE create_Parts(
   IN p_ctx ECD_loader_Types.ctx_t,
   IN p_agr ECD_loader_Types.agr_t
)
AS
$procedure$
DECLARE
   l_result_Code int4;
   l_result_Info varchar;
   r             record;
   l_part        ECD_loader_Types.part_t;
BEGIN

   /*
      Здесь позже:
      - разбор p_agr.parts_xml
      - сбор part_t
      - вызов ecd_loader_Dep.new_Ces_Part(...)
   */

   FOR r IN
      SELECT 1 AS stub_part
   LOOP
      NULL;
   END LOOP;

END;
$procedure$


/* Загрузить историю параметров договора */
CREATE PROCEDURE load_History(
   IN p_ctx ECD_loader_Types.ctx_t,
   IN p_agr ECD_loader_Types.agr_t
)
AS
$procedure$
   #package
BEGIN

   IF p_agr.agr_id IS NULL THEN
      CALL ecd_loader_err.raise_Business_Error (
         'AGR_ID_IS_NULL',
         'Невозможно загрузить историю параметров договора: не задан agr_id.'
      );
   END IF;

   MERGE INTO cdh t
   USING (
      SELECT
         p_agr.agr_id                                                AS ncdhagrid,
         x.npart                                                     AS icdhpart,
         x.ccdhterm                                                  AS ccdhterm,
         CASE
            WHEN x.ccdhterm = 'DISCRATE' THEN p_agr.d_sign
            ELSE x.dcdhdate
         END                                                         AS dcdhdate,
         x.icdhdsub                                                  AS icdhdsub,
         CASE
            WHEN x.ccdhterm = 'DEND' THEN cdces.normalize_Date(x.ccdhcval)
            ELSE x.ccdhcval
         END                                                         AS ccdhcval,
         x.mcdhmval                                                  AS mcdhmval,
         x.icdhival                                                  AS icdhival,
         x.pcdhpval                                                  AS pcdhpval
      FROM (
         SELECT
            xt.npart,
            xt.ccdhterm,
            ecd_loader_xml.get_date_val(xt.dcdhdate_s)               AS dcdhdate,
            ecd_loader_xml.to_numeric(xt.icdhdsub_s)                 AS icdhdsub,
            xt.ccdhcval,
            ecd_loader_xml.to_money(xt.mcdhmval_s)                   AS mcdhmval,
            ecd_loader_xml.to_numeric(xt.icdhival_s)                 AS icdhival,
            ecd_loader_xml.to_percent(xt.pcdhpval_s)                 AS pcdhpval
         FROM XMLTABLE(
            '//CDA_PART/item/CDA_HTERM/item'
            PASSING p_ctx.input_Xml
            COLUMNS
               npart       numeric     PATH './../../@part',
               ccdhterm    varchar(50) PATH 'term',
               dcdhdate_s  varchar(30) PATH 'date',
               icdhdsub_s  varchar(30) PATH 'sub',
               ccdhcval    varchar(50) PATH 'str_value',
               mcdhmval_s  varchar(50) PATH 'sum_value',
               icdhival_s  varchar(50) PATH 'int_value',
               pcdhpval_s  varchar(50) PATH 'percent_value'
         ) xt
      ) x
      WHERE
            x.ccdhterm = 'DISCRATE' OR x.dcdhdate >= p_agr.d_sign
   ) s
   ON (
         t.ncdhagrid = s.ncdhagrid
     AND t.icdhpart  = s.icdhpart
     AND t.ccdhterm  = s.ccdhterm
     AND t.dcdhdate  = s.dcdhdate
     AND coalesce(t.icdhdsub, 0) = coalesce(s.icdhdsub, 0)
   )
   WHEN MATCHED THEN
      UPDATE SET
         ccdhcval = s.ccdhcval,
         mcdhmval = s.mcdhmval,
         icdhival = s.icdhival,
         pcdhpval = s.pcdhpval
   WHEN NOT MATCHED THEN
      INSERT (
         ncdhagrid, icdhpart, ccdhterm, dcdhdate,
         icdhdsub, ccdhcval, mcdhmval, icdhival, pcdhpval
      )
      VALUES (
         s.ncdhagrid, s.icdhpart, s.ccdhterm, s.dcdhdate,
         s.icdhdsub, s.ccdhcval, s.mcdhmval, s.icdhival, s.pcdhpval
      );

   CALL ecd_loader_ret.put_Info( 'cda', 'История параметров договора загружена.', NULL, p_agr.agr_id::varchar );

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      CALL ecd_loader_ret.put_Warn(
         'cda',
         'Договор не найден при загрузке истории параметров.',
         NULL,
         p_agr.agr_id::varchar
      );
   WHEN OTHERS THEN
      CALL ecd_loader_err.rethrow_unhandled( 'ecd_loader_agr.load_History', SQLERRM );
END;
$procedure$


/* Полный цикл обработки договора */
CREATE PROCEDURE load_Agr (
   IN OUT p_ctx ECD_loader_Types.ctx_t,
   IN     p_cus_Id numeric,
   OUT    p_agr    ECD_loader_Types.agr_t
)
AS
$procedure$
BEGIN

   p_agr := parse_Agr(p_ctx, p_cus_Id);

   CALL prepare_Rate    (p_ctx, p_agr);
   CALL resolve_Mda     (p_ctx, p_agr);
   CALL resolve_Agr_Id  (p_ctx, p_agr);
   CALL validate_Agr    (p_ctx, p_agr);
   CALL resolve_Purchase(p_ctx, p_agr);

   CALL create_Agr      (p_ctx, p_agr);
   
   p_ctx.agr_Id := p_agr.agr_id;

   CALL load_History    (p_ctx, p_agr);   

   CALL link_To_Pfl     (p_agr);
   CALL save_Uuid       (p_agr);
   CALL save_Meta       (p_agr);
   CALL save_Purpose    (p_ctx, p_agr);
   CALL save_Ifrs       (p_ctx, p_agr);
   CALL save_Psk        (p_agr);

   CALL create_Parts    (p_ctx, p_agr);
   CALL load_History    (p_ctx, p_agr);

   CALL ECD_loader_Ret.put_Data (
      'cda',
      NULL,
      p_agr.agr_id::varchar
   );

END;
$procedure$

--end_Of_Package
;