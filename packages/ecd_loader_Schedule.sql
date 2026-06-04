CREATE OR REPLACE PACKAGE ecd_loader_Schedule

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   #export off
   DECLARE

      cVersion CONSTANT varchar(100) := '$id: {0.1.0} {10.04.2026} Lora$';

      RET_OK   CONSTANT int4 := 0;
      RET_FAIL CONSTANT int4 := -1;

      cMin_Date CONSTANT date := DATE '1901-01-01';

   BEGIN
      RAISE DEBUG 'Package "ecd_loader_schedule" - % - initialized', cVersion;
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


/* Получить дату подписания договора */
CREATE FUNCTION get_Agr_Sign_Date (
   IN p_agr_Id numeric
)
   RETURNS date
AS
$function$
   #package
DECLARE
   l_dt_Sign date;
BEGIN
   SELECT a.dCdaSignDate
     INTO l_dt_Sign
     FROM cda a
    WHERE a.nCdaAgrID = p_agr_Id;

   RETURN l_dt_Sign;
END;
$function$


/* График основного долга */
CREATE PROCEDURE load_Schedule_Debt (
   IN p_agr_Id numeric,
   IN p_xml    xml
)
AS
$procedure$
   #package
DECLARE
   l_dt_End  date;
   l_dt_Sign date;
   r         record;
   r1        record;
BEGIN

   CALL ecd_loader_Log.dbg('ecd_loader_Schedule.load_Schedule_Debt: agr_Id=' || p_agr_Id::varchar);

   IF NOT ecd_loader_Xml.exists_Node(
      p_xml,
      '//CDA_PART/item/CDA_SCHEDULE/schedule_debt/item'
   ) THEN
      RETURN;
   END IF;

   l_dt_Sign := get_Agr_Sign_Date(p_agr_Id);

   FOR r IN
      SELECT x.nPart,
             x.nCount,
             x.xItem
        FROM XMLTABLE(
           '//CDA_PART/item'
           PASSING p_xml
           COLUMNS
              nPart  numeric PATH '@part',
              nCount numeric PATH 'count(CDA_SCHEDULE/schedule_debt/item)',
              xItem  xml     PATH 'CDA_SCHEDULE/schedule_debt/item'
        ) x
   LOOP

      IF coalesce(r.nCount, 0) = 0 THEN
         CONTINUE;
      END IF;

      DELETE
        FROM cdr_i
       WHERE nCdrAgrID = p_agr_Id
         AND iCdrPart  = r.nPart;

      DELETE
        FROM cdp_i
       WHERE nCdpAgrID = p_agr_Id
         AND iCdpPart  = r.nPart
         AND dCdpExist > cMin_Date;

      INSERT INTO cdr_i (
         nCdrAgrID,
         iCdrPart,
         dCdrDate,
         mCdrSum,
         dCdrExist
      )
      SELECT
         p_agr_Id,
         r.nPart,
         to_date(i.pay_Date_S, 'YYYY-MM-DD'),
         ecd_loader_Xml.to_Money(i.pay_Sum_S),
         coalesce (
            to_date(i.date_Exist_S, 'YYYY-MM-DD'),
            cMin_Date
         )
        FROM XMLTABLE (
           'item'
           PASSING r.xItem
           COLUMNS
              pay_Date_S   varchar(30) PATH 'pay_date',
              pay_Sum_S    varchar(50) PATH 'pay_sum',
              date_Exist_S varchar(30) PATH 'date_exist'
        ) i
       WHERE 
         to_date( i.pay_Date_S, 'YYYY-MM-DD' ) >= l_dt_Sign;

      FOR r1 IN
         SELECT DISTINCT a.dCdrExist
           FROM cdr_i a
          WHERE a.nCdrAgrID = p_agr_Id
            AND a.iCdrPart  = r.nPart
            AND a.dCdrExist > cMin_Date
      LOOP
         INSERT INTO cdp_i(
            nCdpAgrID,
            iCdpPart,
            dCdpDate,
            mCdpSum,
            dCdpExist
         )
         SELECT
            p_agr_Id,
            b.iCdpPart,
            b.dCdpDate,
            b.mCdpSum,
            r1.dCdrExist
           FROM cdp_i b
          WHERE b.nCdpAgrID = p_agr_Id
            AND b.iCdpPart  = r.nPart
            AND b.dCdpExist = cMin_Date;
      END LOOP;

      SELECT max(a.dCdrDate)
        INTO l_dt_End
        FROM cdr_i a
       WHERE a.nCdrAgrID = p_agr_Id
         AND a.dCdrExist = (
            SELECT max(b.dCdrExist)
              FROM cdr_i b
             WHERE b.nCdrAgrID = p_agr_Id
         );

      IF l_dt_End IS NOT NULL THEN
         CALL ecd_loader_Dep.update_History(
            p_agr_Id,
            r.nPart,
            'DEND',
            l_dt_Sign,
            NULL,
            to_char(l_dt_End, 'DD.MM.YYYY'),
            NULL,
            NULL
         );
      END IF;

   END LOOP;

END;
$procedure$


/* График выдачи основного долга */
CREATE PROCEDURE load_Schedule_Cred(
   IN p_agr_Id numeric,
   IN p_xml    xml
)
AS
$procedure$
DECLARE
   r record;
BEGIN

   CALL ecd_loader_Log.dbg('ecd_loader_Schedule.load_Schedule_Cred: agr_Id=' || p_agr_Id::varchar);

   IF NOT ecd_loader_Xml.exists_Node(
      p_xml,
      '//CDA_PART/item/CDA_SCHEDULE/schedule_cred/item'
   ) THEN
      CALL ECD_loader_Log.dbg( 'График выдачи основного долга - отсутсвтует');
      RETURN;
   END IF;

   FOR r IN
      SELECT x.nPart,
             x.isProl,
             x.nCount,
             x.xItem
        FROM XMLTABLE(
           '//CDA_PART/item'
           PASSING p_xml
           COLUMNS
              nPart  numeric PATH '@part',
              isProl numeric PATH 'is_prol',
              nCount numeric PATH 'count(CDA_SCHEDULE/schedule_cred/item)',
              xItem  xml     PATH 'CDA_SCHEDULE/schedule_cred/item'
        ) x
   LOOP

      IF coalesce( r.nCount, 0 ) = 0 THEN
         CONTINUE;
      END IF;

      IF r.nPart = 1 OR coalesce(r.isProl, 0) <> 1 THEN
         CONTINUE;
      END IF;

      DELETE
        FROM cdp_i
       WHERE nCdpAgrID = p_agr_Id
         AND iCdpPart  = r.nPart;

      INSERT INTO cdp_i(
         nCdpAgrID,
         iCdpPart,
         dCdpDate,
         mCdpSum,
         dCdpExist
      )
      SELECT
         p_agr_Id,
         r.nPart,
         to_date(i.pay_Date_S, 'YYYY-MM-DD'),
         ecd_loader_Xml.to_Money(i.pay_Sum_S),
         coalesce(
            to_date(i.date_Exist_S, 'YYYY-MM-DD'),
            cMin_Date
         )
        FROM XMLTABLE(
           'item'
           PASSING r.xItem
           COLUMNS
              pay_Date_S   varchar(30) PATH 'pay_date',
              pay_Sum_S    varchar(50) PATH 'pay_sum',
              date_Exist_S varchar(30) PATH 'date_exist'
        ) i;

   END LOOP;

END;
$procedure$


/* Графики процентов */
CREATE PROCEDURE load_Schedule_Percent(
   IN p_ctx    ecd_loader_types.ctx_t,
   IN p_agr_Id numeric,
   IN p_xml    xml
)
AS
$procedure$
DECLARE
   l_d_From      date;
   l_b_Date      date;
   l_result_Info varchar;
   l_ret         boolean;
   r             record;
BEGIN

   CALL ecd_loader_Log.dbg('ecd_loader_Schedule.load_Schedule_Percent: agr_Id=' || p_agr_Id::varchar);

   IF ecd_loader_Xml.exists_Node(
      p_xml,
      '//CDA_SCHEDULE/schedule_percent/item'
   ) THEN

      SELECT min(to_date(x.pay_Date_S, 'YYYY-MM-DD'))
        INTO l_d_From
        FROM XMLTABLE(
           '//CDA_SCHEDULE/schedule_percent/item'
           PASSING p_xml
           COLUMNS
              pay_Date_S varchar(30) PATH 'endIntervalDate'
        ) x;

      CALL CDCes.Clear_Shdl_PC_from(
         AgrID     => p_agr_Id,
         dateFrom  => l_d_From,
         DO_COMMIT => FALSE
      );

      INSERT INTO cds(
         nCdsAgrID,
         dCdsIntCalcDate,
         dCdsIntPmtDate,
         dCdsIntPmtStart
      )
      SELECT
         p_agr_Id,
         to_date(x.end_Interval_Date_S, 'YYYY-MM-DD'),
         to_date(x.pay_Date_S,          'YYYY-MM-DD'),
         to_date(x.pay_Date_S,          'YYYY-MM-DD')
        FROM XMLTABLE(
           '//CDA_SCHEDULE/schedule_percent/item'
           PASSING p_xml
           COLUMNS
              end_Interval_Date_S varchar(30) PATH 'endIntervalDate',
              pay_Date_S          varchar(30) PATH 'pay_date'
        ) x
       WHERE to_date(x.end_Interval_Date_S, 'YYYY-MM-DD') >
             (SELECT a.dCdaSignDate
                FROM cda a
               WHERE a.nCdaAgrID = p_agr_Id);

   END IF;

   IF ecd_loader_Xml.exists_Node(
      p_xml,
      '//CDA_PART/item/CDA_SCHEDULE/schedule_adj_percent/item'
   ) THEN

      FOR r IN
         SELECT x.nPart,
                x.nCount,
                x.xItem
           FROM XMLTABLE(
              '//CDA_PART/item'
              PASSING p_xml
              COLUMNS
                 nPart  numeric PATH '@part',
                 nCount numeric PATH 'count(CDA_SCHEDULE/schedule_adj_percent/item)',
                 xItem  xml     PATH 'CDA_SCHEDULE/schedule_adj_percent/item'
           ) x
      LOOP

         IF coalesce(r.nCount, 0) = 0 THEN
            CONTINUE;
         END IF;

         DELETE
           FROM cd_imps
          WHERE nCdiAgrID = p_agr_Id
            AND nCdiPart  = r.nPart
            AND cCdiMPType = 'PC';

         INSERT INTO cd_imps(
            nCdiAgrID,
            nCdiPart,
            cCdiMPType,
            dCdiDate,
            mCdiSum,
            iCdiStatus
         )
         SELECT
            p_agr_Id,
            r.nPart,
            'PC',
            to_date(i.pay_Date_S, 'YYYY-MM-DD'),
            ecd_loader_Xml.to_Money(i.pay_Sum_S),
            0
           FROM XMLTABLE(
              'item'
              PASSING r.xItem
              COLUMNS
                 pay_Date_S varchar(30) PATH 'pay_date',
                 pay_Sum_S  varchar(50) PATH 'pay_sum'
           ) i;

      END LOOP;

   END IF;

   IF ecd_loader_Xml.exists_Node(
      p_xml,
      '//CDA_PART/item/CDA_SCHEDULE/schedule_dfr_percent/item'
   ) THEN

      FOR r IN
         SELECT x.nPart,
                x.nCount,
                x.xItem
           FROM XMLTABLE(
              '//CDA_PART/item'
              PASSING p_xml
              COLUMNS
                 nPart  numeric PATH '@part',
                 nCount numeric PATH 'count(CDA_SCHEDULE/schedule_dfr_percent/item)',
                 xItem  xml     PATH 'CDA_SCHEDULE/schedule_dfr_percent/item'
           ) x
      LOOP

         IF coalesce(r.nCount, 0) = 0 THEN
            CONTINUE;
         END IF;

         DELETE
           FROM cd_imps
          WHERE nCdiAgrID = p_agr_Id
            AND nCdiPart  = r.nPart
            AND cCdiMPType = 'O';

         INSERT INTO cd_imps(
            nCdiAgrID,
            nCdiPart,
            cCdiMPType,
            dCdiDate,
            mCdiSum,
            iCdiStatus
         )
         SELECT
            p_agr_Id,
            r.nPart,
            'O',
            to_date(i.pay_Date_S, 'YYYY-MM-DD'),
            ecd_loader_Xml.to_Money(i.pay_Sum_S),
            0
           FROM XMLTABLE(
              'item'
              PASSING r.xItem
              COLUMNS
                 pay_Date_S varchar(30) PATH 'pay_date',
                 pay_Sum_S  varchar(50) PATH 'pay_sum'
           ) i;

      END LOOP;

   END IF;

   IF ecd_loader_Xml.exists_Node(
      p_xml,
      '//CDA_PART/item/CDA_SCHEDULE/schedule_csn_percent/item'
   ) THEN

      DELETE
        FROM cd_sces
       WHERE nCdsCesAgrId = p_agr_Id;

      FOR r IN
         SELECT x.nPart,
                x.nCount,
                x.xItem
           FROM XMLTABLE(
              '//CDA_PART/item'
              PASSING p_xml
              COLUMNS
                 nPart  numeric PATH '@part',
                 nCount numeric PATH 'count(CDA_SCHEDULE/schedule_csn_percent/item)',
                 xItem  xml     PATH 'CDA_SCHEDULE/schedule_csn_percent/item'
           ) x
      LOOP

         IF coalesce(r.nCount, 0) = 0 THEN
            CONTINUE;
         END IF;

         INSERT INTO cd_sces(
            nCdsCesAgrId,
            iCdsCesPart,
            dCdsCesPmtD,
            mCdsCesSum
         )
         SELECT
            p_agr_Id,
            r.nPart,
            to_date(i.csn_Date_S, 'YYYY-MM-DD'),
            ecd_loader_Xml.to_Money(i.csn_Sum_S)
           FROM XMLTABLE(
              'item'
              PASSING r.xItem
              COLUMNS
                 csn_Date_S varchar(30) PATH 'csn_date',
                 csn_Sum_S  varchar(50) PATH 'csnsum'
           ) i;

      END LOOP;

   END IF;

   IF p_ctx.correct_schedule_percent THEN
      CALL CDCes.CorrSum_PC(p_agr_Id, l_d_From);

      CALL ecd_loader_Ret.put_Info(
         'cda',
         'Выполнена коррекция сумм'
      );
   END IF;

   l_b_Date := ecd_loader_Xml.get_Date_Val(
      p_xml,
      '//CDA_DATE/item[@id="cession_buy"]/text()'
   );

   IF l_b_Date IS NOT NULL THEN
      l_ret := CDCes.Corr_IntCalcSum(
         p_agr_Id,
         l_b_Date,
         l_result_Info
      );

      IF NOT l_ret THEN
         CALL ecd_loader_Ret.put_Error(
            'cda',
            'Ошибка выполнения коррекции суммы процентов: ' || coalesce(l_result_Info, '<NULL>')
         );
      ELSE
         CALL ecd_loader_Ret.put_Info(
            'cda',
            coalesce(
               l_result_Info,
               'Выполнена коррекция суммы процентов на первом интервале по расчетной сумме процентов'
            )
         );
      END IF;
   END IF;

END;
$procedure$

/* График платежей */
CREATE PROCEDURE load_Schedule_Payment(
   IN p_agr_Id numeric,
   IN p_xml    xml
)
AS
$procedure$
DECLARE
   r record;
BEGIN

   CALL ecd_loader_Log.dbg('ecd_loader_Schedule.load_Schedule_Payment: agr_Id=' || p_agr_Id::varchar);

   IF NOT ecd_loader_Xml.exists_Node(
      p_xml,
      '//CDA_PART/item/CDA_SCHEDULE/schedule_payment/item'
   ) THEN
      RETURN;
   END IF;

   FOR r IN
      SELECT x.nPart,
             x.nCount,
             x.xItem
        FROM XMLTABLE(
           '//CDA_PART/item'
           PASSING p_xml
           COLUMNS
              nPart  numeric PATH '@part',
              nCount numeric PATH 'count(CDA_SCHEDULE/schedule_payment/item)',
              xItem  xml     PATH 'CDA_SCHEDULE/schedule_payment/item'
        ) x
   LOOP

      IF coalesce(r.nCount, 0) = 0 THEN
         CONTINUE;
      END IF;

      DELETE
        FROM cd_grp_ces
       WHERE nGrpCesDog  = p_agr_Id
         AND iGrpCesPart = r.nPart;

      INSERT INTO cd_grp_ces(
         nGrpCesDog,
         iGrpCesPart,
         dGrpCesDat,
         dGrpCesFrom,
         dGrpCesTo,
         mGrpCesPayL,
         mGrpCesPayI,
         mGrpCesPay
      )
      SELECT
         p_agr_Id,
         r.nPart,
         to_date(i.pay_Date_S,         'YYYY-MM-DD'),
         to_date(i.beg_Interval_Date_S,'YYYY-MM-DD'),
         to_date(i.end_Interval_Date_S,'YYYY-MM-DD'),
         coalesce(ecd_loader_Xml.to_Money(i.pay_Debt_S),    0),
         coalesce(ecd_loader_Xml.to_Money(i.pay_Percent_S), 0),
         coalesce(ecd_loader_Xml.to_Money(i.pay_Sum_S),     0)
        FROM XMLTABLE(
           'item'
           PASSING r.xItem
           COLUMNS
              pay_Date_S          varchar(30) PATH 'pay_date',
              beg_Interval_Date_S varchar(30) PATH 'begIntervalDate',
              end_Interval_Date_S varchar(30) PATH 'endIntervalDate',
              pay_Sum_S           varchar(50) PATH 'pay_sum',
              pay_Debt_S          varchar(50) PATH 'pay_debt',
              pay_Percent_S       varchar(50) PATH 'pay_percent'
        ) i;

   END LOOP;

END;
$procedure$


/* График просрочки */
CREATE PROCEDURE load_Schedule_Overdue (
   IN p_agr_Id numeric,
   IN p_xml    xml
)
AS
   $procedure$
DECLARE
   r record;
BEGIN

   CALL ecd_loader_Log.dbg( 'ecd_loader_Schedule.load_Schedule_Overdue: agr_Id=' || p_agr_Id::varchar );

   IF NOT ecd_loader_Xml.exists_Node (
      p_xml,
      '//CDA_PART/item/CDA_SCHEDULE/schedule_overdue/item'
   ) THEN
      RETURN;
   END IF;

   FOR r IN

      SELECT x.nPart, x.nCount, x.xItem
        FROM XMLTABLE (
           '//CDA_PART/item'
           PASSING p_xml
           COLUMNS
              nPart  numeric PATH '@part',
              nCount numeric PATH 'count(CDA_SCHEDULE/schedule_overdue/item)',
              xItem  xml     PATH 'CDA_SCHEDULE/schedule_overdue/item'
        ) x

      LOOP

         IF coalesce( r.nCount, 0) = 0 THEN
            CONTINUE;
         END IF;

         DELETE
           FROM CD_Cdo_Ces
          WHERE 
                nCdoCesAgrID = p_Agr_Id AND iCdoCesPart  = r.nPart;

         INSERT INTO cd_cdo_ces( nCdoCesAgrID, iCdoCesPart, dCdoCesStart, dCdoCesDate, mCdoCesOverdue, cCdoCesType )
              SELECT p_agr_Id, r.nPart, to_date(i.dtBeg_S, 'YYYY-MM-DD'), to_date(i.dtChange_S, 'YYYY-MM-DD'), 
                     coalesce(ecd_loader_Xml.to_Money(i.overdue_Sum_S), 0), i.overdue_Type
           FROM XMLTABLE (
              'item'
              PASSING r.xItem
              COLUMNS
                 dtBeg_S       varchar(30) PATH 'dtbeg',
                 dtChange_S    varchar(30) PATH 'dtchange',
                 overdue_Sum_S varchar(50) PATH 'overdue_sum',
                 overdue_Type  varchar(30) PATH 'type'
         ) i;

   END LOOP;

END;
$procedure$


/* Общая загрузка всех графиков */
CREATE PROCEDURE load_All(
   IN p_ctx    ecd_loader_types.ctx_t,
   IN p_agr_Id numeric,
   IN p_xml    xml
)
AS
$procedure$
BEGIN

   CALL load_Schedule_Debt   (p_agr_Id, p_xml);
   CALL load_Schedule_Cred   (p_agr_Id, p_xml);
   CALL load_Schedule_Percent(p_ctx,    p_agr_Id, p_xml);
   CALL load_Schedule_Payment(p_agr_Id, p_xml);
   CALL load_Schedule_Overdue(p_agr_Id, p_xml);

END;
$procedure$

--end_Of_Package
;