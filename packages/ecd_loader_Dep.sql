CREATE OR REPLACE PACKAGE ecd_loader_Dep

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   #export off
   DECLARE
      cVersion CONSTANT varchar(100) := '$id: {0.2.0} {02.06.2026} Lora$';

      RET_OK   CONSTANT int4 := 0;
      RET_FAIL CONSTANT int4 := -1;
   BEGIN
      RAISE DEBUG 'Package "ecd_loader_dep" - % - initialized', cVersion;
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


/* Создание клиента */
CREATE PROCEDURE create_Cus(
   IN  p_xml         xml,
   IN  p_run_Mfv     int4,
   OUT p_cus_Id      numeric,
   OUT p_result_Code int4,
   OUT p_result_Info varchar
)
AS
$procedure$
BEGIN

   p_cus_Id      := NULL;
   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   CALL ECD_loader_Log.dbg('ecd_loader_Dep.create_Cus');

   call K_pkgCUS.create_Cus( p_xml, p_run_Mfv, p_cus_Id, p_result_Code, p_result_Info );

EXCEPTION
   WHEN OTHERS THEN
      p_cus_Id      := NULL;
      p_result_Code := RET_FAIL;
      p_result_Info := SQLERRM;
      CALL ecd_loader_Log.err(
         'ecd_loader_Dep.create_Cus: ' || coalesce(p_result_Info, '<NULL>')
      );
END;
$procedure$


/* Создание кредитного договора цессии */
CREATE PROCEDURE new_Ces(
   IN  p_agr         ECD_loader_Types.agr_t,
   OUT p_result_Code int4,
   OUT p_result_Info varchar
)
AS
$procedure$
   #package
DECLARE
   l_ret varchar;
BEGIN

   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   CALL ecd_loader_Log.dbg (
      'ecd_loader_Dep.new_Ces: agr_Id=' || coalesce( p_agr.agr_id::varchar, '<NULL>' )
   );

   l_ret := CDCes.New_Ces(
      AgrID         => p_agr.agr_id,
      CD_Sum        => p_agr.total_sum,
      Pay_Sum       => NULL::numeric,
      MDA_Num       => p_agr.mda_id,
      CurCliNum     => p_agr.cus_id,
      CurCliAcc     => NULL::varchar,
      CurStatus     => 0::numeric,
      pZID          => NULL::numeric,
      pDEnd         => p_agr.dt_end,
      pAGRMNT       => p_agr.ext_num,
      pDSign        => p_agr.d_sign,
      pDPurch       => p_agr.dt_buy,
      pMPurch       => p_agr.amount_agr,
      pDFirstPay    => NULL::date,
      pMFirstPay    => NULL::numeric,
      pDFirstPay_A  => p_agr.d_first_pay_a,
      pNTimeY       => p_agr.ntime_y::numeric,
      pNTimeM       => p_agr.ntime_m::numeric,
      pNTimeD       => p_agr.ntime_d::numeric,
      pMBONSum      => p_agr.premium_sum,
      pNCesType     => p_agr.purchase_type,
      pNKD          => p_agr.coeff_discount,
      pCOWD         => p_agr.owd,
      pcFR          => p_agr.fin_res,
      pPRC          => p_agr.ext_percent,
      pNDTN_A       => p_agr.annuity_day::numeric,
      pDOUTFD       => p_agr.d_date_of_issue
   );

   IF l_ret = 'OK' THEN
      p_result_Code := RET_OK;
   ELSE
      p_result_Code := RET_FAIL;
      p_result_Info := l_ret;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      p_result_Code := RET_FAIL;
      p_result_Info := SQLERRM;
      CALL ecd_loader_Log.err(
         'ecd_loader_Dep.new_Ces: ' || coalesce(p_result_Info, '<NULL>')
      );
END;
$procedure$


/* Создание части договора */
CREATE PROCEDURE new_Ces_Part(
   IN  p_part        ECD_loader_Types.part_t,
   OUT p_result_Code int4,
   OUT p_result_Info varchar
)
AS
$procedure$
   #package
DECLARE
   l_ret      varchar;
   l_new_Part CDCes.Part_Details;
BEGIN

   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   CALL ecd_loader_Log.dbg (
      'ecd_loader_Dep.new_Ces_Part: agr_Id=' || coalesce(p_part.agr_id::varchar, '<NULL>') || ', part=' || coalesce(p_part.part_no::varchar, '<NULL>')
   );

   /*
      Преобразование ECD_loader_Types.part_t -> CDCes.Part_Details
   */
   l_new_Part.agrId  := p_part.agr_id;
   l_new_Part.part   := p_part.part_no;
   l_new_Part.pDbeg  := p_part.dt_buy;
   l_new_Part.pDend  := p_part.dt_end;
   l_new_Part.pPI    := p_part.ext_percent;
   l_new_Part.pPFA   := p_part.penalty_debt;
   l_new_Part.pPFI   := p_part.penalty_percent;
   l_new_Part.pMSum  := p_part.amount_agr;
   l_new_Part.pMI    := p_part.current_percent_sum;
   l_new_Part.pMO    := p_part.overdue_sum;
   l_new_Part.pMOI   := p_part.overdue_percent_sum;
   l_new_Part.pMFA   := p_part.fine_main_sum;
   l_new_Part.pMFI   := p_part.fine_percent_sum;
   l_new_Part.pMI2   := p_part.current_percent_overdue_sum;
   l_new_Part.pMOI2  := p_part.overdue_percent_overdue_sum;
   l_new_Part.pMC    := p_part.commission_sum;
   l_new_Part.pNNDO  := p_part.days_of_delay;
   l_new_Part.pISPROL:= CASE WHEN p_part.is_prol THEN '1' ELSE '0' END;
   l_new_Part.pNICLC := p_part.calc_percent_sum;
   l_new_Part.pPFI2  := p_part.penalty_overdue;

   l_ret := CDCes.New_Ces_Part( newPart => l_new_Part );

   IF l_ret = 'OK' THEN
      p_result_Code := RET_OK;
   ELSE
      p_result_Code := RET_FAIL;
      p_result_Info := l_ret;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      p_result_Code := RET_FAIL;
      p_result_Info := SQLERRM;
      CALL ecd_loader_Log.err(
         'ecd_loader_Dep.new_Ces_Part: ' || coalesce(p_result_Info, '<NULL>')
      );
END;
$procedure$


/* Обновление истории параметров */
CREATE PROCEDURE update_History(
   IN p_agr_Id  numeric,
   IN p_part    numeric,
   IN p_term    varchar,
   IN p_dt      date,
   IN p_n_Val   numeric,
   IN p_c_Val   varchar,
   IN p_p_Val   numeric,
   IN p_i_Val   numeric DEFAULT NULL
)
AS
$procedure$
BEGIN

   IF coalesce(p_n_Val, p_c_Val, p_p_Val, p_i_Val::varchar) IS NULL THEN
      RETURN;
   END IF;

   IF p_term = 'DEND' THEN
   
      CALL CDTerms.Update_History(
         agrid       => p_agr_Id,
         part        => p_part,
         term        => p_term,
         effdate     => p_dt,
         mval        => p_n_Val,
         pval        => p_p_Val,
         ival0       => p_i_Val::bigint,
         cval        => CDCes.Normalize_Date(p_c_Val),
         flaghistory => NULL::bigint
      );

   ELSE

      CALL CDTerms.Update_History(
         agrid       => p_agr_Id,
         part        => p_part,
         term        => p_term,
         effdate     => p_dt,
         mval        => p_n_Val,
         pval        => p_p_Val,
         ival0       => p_i_Val::bigint,
         cval        => p_c_Val,
         flaghistory => NULL::bigint
      );

   END IF;
END;
$procedure$


/* Сохранение UUID */
CREATE PROCEDURE merge_Cb_Uuid(
   IN  p_agr_Id      numeric,
   IN  p_uuid        varchar,
   OUT p_result_Code int4,
   OUT p_result_Info varchar
)
AS
$procedure$
DECLARE
   l_ret int4;
BEGIN

   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   CALL DG_cbUuid.merge_Extern_CBUUID(
      pn_subsys       => 27,
      pn_objid        => p_agr_Id,
      pc_externuuid   => p_uuid,
      pi_result       => l_ret,
      pc_errormessage => p_result_Info
   );

   IF l_ret = 0 THEN
      p_result_Code := RET_OK;
   ELSE
      p_result_Code := RET_FAIL;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      p_result_Code := RET_FAIL;
      p_result_Info := SQLERRM;
END;
$procedure$


/* Установка стадии МСФО */
CREATE PROCEDURE set_Ifrs_Stage(
   IN  p_agr_Id      numeric,
   IN  p_cus_Id      numeric,
   IN  p_stage_Id    numeric,
   OUT p_result_Code int4,
   OUT p_result_Info varchar
)
AS
$procedure$
BEGIN

   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   IF CDUtil_IFRS.set_IFRS_Stg(
         pAgrID   => p_agr_Id,
         pSbSysID => 27,
         pCusID   => p_cus_Id,
         pStg     => p_stage_Id,
         pErr     => p_result_Info
      ) = 0
   THEN
      p_result_Code := RET_FAIL;
   ELSE
      p_result_Code := RET_OK;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      p_result_Code := RET_FAIL;
      p_result_Info := SQLERRM;
END;
$procedure$


/* Вызов handler-а клиента
CREATE PROCEDURE run_Cus_Handler(
   IN  p_cus_Id       numeric,
   IN  p_is_New       int4,
   IN  p_cus_Type     int4,
   IN  p_agr_Cur      varchar,
   OUT p_result_Code  int4,
   OUT p_result_Info  varchar
)
AS
$procedure$
DECLARE
   tabParamImpl  AC.T_TabParameterImpl;
   tabResultImpl AC.T_TabParameterImpl;
BEGIN

   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   tabParamImpl('p1') := p_cus_Id;
   tabParamImpl('p2') := p_is_New;
   tabParamImpl('p3') := p_cus_Type;
   tabParamImpl('p4') := p_agr_Cur;

   AC.Get_TabValueImpl(
      tabResultImpl,
      'ECD.Cus_Handler',
      tabParamImpl
   );

   IF tabResultImpl('o1')::numeric = -1 THEN
      p_result_Code := RET_FAIL;
      p_result_Info := tabResultImpl('o2');
   ELSE
      p_result_Code := RET_OK;
      p_result_Info := tabResultImpl('o2');
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      p_result_Code := RET_FAIL;
      p_result_Info := SQLERRM;
END;
$procedure$
 

/* Вызов handler-а счетов */
CREATE PROCEDURE run_Acc_Handler(
   IN  p_agr_Id       numeric,
   OUT p_result_Code  int4,
   OUT p_result_Info  varchar
)
AS
$procedure$
DECLARE
   tabParamImpl  AC.T_TabParameterImpl;
   tabResultImpl AC.T_TabParameterImpl;
BEGIN

   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   tabParamImpl('p1') := p_agr_Id;

   AC.Get_TabValueImpl(
      tabResultImpl,
      'ECD.Acc_Handler',
      tabParamImpl
   );

   IF tabResultImpl('o1')::numeric = -1 THEN
      p_result_Code := RET_FAIL;
      p_result_Info := tabResultImpl('o2');
   ELSE
      p_result_Code := RET_OK;
      p_result_Info := tabResultImpl('o2');
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      p_result_Code := RET_FAIL;
      p_result_Info := SQLERRM;
END;
$procedure$
*/

/* Пересчет оборотки */
CREATE PROCEDURE recalc_Balance(
   IN  p_agr_Id       numeric,
   OUT p_result_Code  int4,
   OUT p_result_Info  varchar
)
AS
$procedure$
BEGIN

   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   CALL CDBALANCE.ReSet_Saldo_DOG( p_agr_Id );
   CALL CDBALANCE.ReSet_CDRR_DOG ( p_agr_Id );

   p_result_Code := RET_OK;

EXCEPTION
   WHEN OTHERS THEN
      p_result_Code := RET_FAIL;
      p_result_Info := SQLERRM;
END;
$procedure$


/* Перевод договора в рабочий */
CREATE PROCEDURE make_Working(
   IN  p_agr_Id       numeric,
   OUT p_result_Code  int4,
   OUT p_result_Info  varchar
)
AS
$procedure$
DECLARE
   l_err_Msg varchar;
BEGIN

   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   IF CDState.check_Agr_Cnd( p_agr_Id, l_err_Msg ) THEN

      UPDATE xxi."CDA"
         SET iCdaStatus = 1
       WHERE 
             nCdaAgrID  = p_agr_Id;

      IF CDState.guess_And_Set_Status( p_agr_Id ) IS NOT NULL THEN
         p_result_Code := RET_OK;
         p_result_Info := 'Договор переведен в действующий статус.';
      ELSE
         p_result_Code := RET_FAIL;
         p_result_Info := 'Не удалось перевести договор в действующий статус.';
      END IF;

   ELSE

      p_result_Code := RET_FAIL;
      p_result_Info := l_err_Msg;

   END IF;

EXCEPTION
   WHEN OTHERS THEN
      p_result_Code := RET_FAIL;
      p_result_Info := SQLERRM;
END;
$procedure$


/* Установка доп. атрибута */
CREATE PROCEDURE set_Attr_Value(
   IN     p_location_Id numeric,
   IN OUT p_extend_Id   numeric,
   IN     p_attr_Id     numeric,
   IN     p_value       varchar
)
AS
$procedure$
BEGIN
   CALL Attribute_Pkg.Set_Value(
      pLocationId  => p_location_Id,
      pExtendId    => p_extend_Id,
      pAttributeId => p_attr_Id,
      pParentId    => NULL,
      pValue       => p_value
   );
END;
$procedure$

--end_Of_Package
;