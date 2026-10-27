-----------------------------------------------------------------------------
--
--  Logical unit: InterimDemandHead
--  Component:    ORDSTR
--
--  IFS Developer Studio Template Version 3.0
--
--  Date    Sign    History
--  ------  ------  ---------------------------------------------------------
--  260910  MC0C127911 M-MRO-048-11 : Bug Id#28784 Modified Update___ to set c_cost_upd_after_spmt_crea to 'FALSE' when line level have NULL Cost Type records.(SEBSA)
--  260722  GS0C130869 M-MRO-009  : (Bug Fixing : 28208) Modified C_Get_Remaining_Life enhanced Remaining Life calculation to use Part Revision while fetching life limit values.
--  250408  BR0C130841 M-MRO-048  : (Bug Fixing : 26836) Created a new method C_Camro_Cro_Cost_Details_
--  251231  HT0C130865 M-MRO-264  : (Bug ID - 25301) Created function C_Check_Work_Completion
--  250724  BR0C122032 M-MRO-010          : Created New Function C_Reason_For_Incl
--  250704  TecvijayG  M-MRO-117  : Added methods C_Get_Cus_No and C_Get_Cont_Dtls.
--  250213 BK0C119713  B-FS-M-MRO-048-6: Added C_Get_Tag_Tos (SEBSA).
--  240628  TecGovinT  M-MRO-010          : Modified - Added C_Modify method
--  240416 TecPardhY   M-MRO-098-Bug 12195: Modified C_Get_Remaining_Life to add conditions in the cursor get_maint_oper_params
--  240327 TecKiranK   M-MRO-098: Modified Interim_Demand_Head for Bug Id 12316
--  231108 DC0C117601  B-FS-M-MRO-048 Modified Check_Insert___ to add a default Camro Cro Cost state.
-----------------------------------------------------------------------------

layer Cust;

-------------------- PUBLIC DECLARATIONS ------------------------------------


-------------------- PRIVATE DECLARATIONS -----------------------------------


-------------------- LU SPECIFIC IMPLEMENTATION METHODS ---------------------
@Override
PROCEDURE Check_Insert___ (
   newrec_ IN OUT NOCOPY interim_demand_head_tab%ROWTYPE,
   indrec_ IN OUT NOCOPY Indicator_Rec,
   attr_   IN OUT NOCOPY VARCHAR2 )
IS   
BEGIN   
   -- (+) 231108 DC0C117601 B-FS-M-MRO-048 (START)
   IF (newrec_.c_camro_cro_state IS NULL) THEN
      newrec_.c_camro_cro_state := 'InProgress';
   END IF;
   -- (+) 231108 DC0C117601 B-FS-M-MRO-048 (FINISH)
   Super(newrec_,indrec_, attr_);   
END Check_Insert___;

@Override 
PROCEDURE Update___ (
   objid_      IN     VARCHAR2,
   oldrec_     IN     interim_demand_head_tab%ROWTYPE,
   newrec_     IN OUT NOCOPY interim_demand_head_tab%ROWTYPE,
   attr_       IN OUT NOCOPY VARCHAR2,
   objversion_ IN OUT NOCOPY VARCHAR2,
   by_keys_    IN     BOOLEAN DEFAULT FALSE )
IS
   -- (+) 260910 MC0C127911 M-MRO-048-11 (START)
   err_msg_count_    NUMBER := 0;
   
   CURSOR get_error_msg_count IS
      SELECT COUNT(t.error_message) 
      FROM   c_camro_cro_cost_details_tab t
      WHERE  t.interim_header_id = newrec_.interim_header_id
      AND    t.contract          = newrec_.contract;
   -- (+) 260910 MC0C127911 M-MRO-048-11 (FINISH)
BEGIN
   -- (+) 260910 MC0C127911 M-MRO-048-11 (START)
   OPEN  get_error_msg_count;
   FETCH get_error_msg_count INTO err_msg_count_;
   CLOSE get_error_msg_count;
   
   IF (err_msg_count_ != 0) THEN
      newrec_.c_cost_upd_after_spmt_crea := 'FALSE';
   END IF;
   -- (+) 260910 MC0C127911 M-MRO-048-11 (FINISH)
   
   super(objid_, oldrec_, newrec_, attr_, objversion_, by_keys_);
END Update___;  


-------------------- LU SPECIFIC PRIVATE METHODS ----------------------------


-------------------- LU SPECIFIC PROTECTED METHODS --------------------------


-------------------- LU SPECIFIC PUBLIC METHODS -----------------------------


-------------------- LU CUST NEW METHODS -------------------------------------
-- (+) 231108 DC0C117601 B-FS-M-MRO-048 (START)
PROCEDURE C_Modify_Camro_Cro_State (
   interim_header_id_ IN VARCHAR2,
   state_             IN VARCHAR2 )
IS
   attr_                  VARCHAR2(2000);
   objid_                 VARCHAR2(2000);
   objversion_            VARCHAR2(2000);
   newrec_                INTERIM_DEMAND_HEAD_TAB%ROWTYPE;
   oldrec_                INTERIM_DEMAND_HEAD_TAB%ROWTYPE;
   indrec_                Indicator_Rec;
BEGIN
   Client_SYS.Clear_Attr(attr_);
   Client_SYS.Add_To_Attr('C_CAMRO_CRO_STATE_DB', state_, attr_);
   
   oldrec_ := Lock_By_Keys___(interim_header_id_);
   newrec_ := oldrec_;
   Unpack___(newrec_, indrec_, attr_);
   Check_Update___(oldrec_, newrec_, indrec_, attr_);
   Update___(objid_, oldrec_, newrec_, attr_, objversion_, TRUE);
END C_Modify_Camro_Cro_State;
-- (+) 231108 DC0C117601 B-FS-M-MRO-048 (FINISH)

--(+) 260722 GS0C130869 M-MRO-009 (Bug ID : 28208)(START) 
-- Updated the Remaining Life calculation to retrieve life limit values using
-- Part Revision and template information from the serial structure. This fixes
-- duplicate Remaining Life values by ensuring the life limit definition is
-- fetched for the correct part revision.

-- (+) 240327  TecKiranK  M-MRO-098 (START)
FUNCTION C_Get_Remaining_Life(
   part_no_    IN  VARCHAR2,
   serial_no_  IN  VARCHAR2
   ) RETURN VARCHAR2
IS
   result_                   VARCHAR2(4000);
   calc_value_               NUMBER;
   remaining_value_1_        NUMBER;
   remaining_value_2_        NUMBER;
   remaining_value_3_        NUMBER;
   $IF Component_Vim_SYS.INSTALLED $THEN
      life_limited_             vim_serial_tab.life_limited%TYPE;
      current_stress_rating_    vim_serial_tab.current_stress_rating%TYPE;
      oper_param_1_             serial_oper_log_tab.oper_param%TYPE;
      oper_param_2_             serial_oper_log_tab.oper_param%TYPE;
      oper_param_3_             serial_oper_log_tab.oper_param%TYPE;
      part_rev_                 Vim_Serial_Structure_TAB.part_rev%TYPE;
      top_part_                 Vim_Serial_Structure_TAB.top_part_no%TYPE;
      top_part_rev_             Vim_Serial_Structure_TAB.top_part_rev%TYPE;
     
   CURSOR get_stress_ratings(part_no_ VARCHAR2,serial_no_ VARCHAR2) IS
      SELECT Vim_Part_Life_Limit_API.Decode(vs.life_limited),
             vs.current_stress_rating
      FROM   vim_serial_tab vs
      WHERE  vs.part_no   = part_no_
      AND    vs.serial_no = serial_no_;
      
   --(+) 260722 GS0C130869 M-MRO-009 (Bug ID : 28208)(START) 
   -- Fetch life limit values using Part Number, Part Revision,
   -- Template Part Number, Template Part Revision, and Stress Rating
   -- to uniquely identify the applicable life limit record.
   CURSOR get_life_limit_values( part_no_               VARCHAR2,
                                 part_rev_              Vim_Serial_Structure_TAB.part_rev%TYPE,
                                 top_part_              Vim_Serial_Structure_TAB.top_part_no%TYPE,
                                 top_part_rev_          Vim_Serial_Structure_TAB.top_part_rev%TYPE,
                                 current_stress_rating_ VARCHAR2) IS

      SELECT oper_param,
             life_limit
      FROM   Op_Life_Limit_Per_Part_TAB
      WHERE  part_no           = part_no_
      AND    part_rev          = part_rev_
      AND    template_part_no  = top_part_       -- Template Part No in Manage ser structure screen
      AND    template_part_rev = top_part_rev_   -- Template Part Rev NO in Manage ser structure screen
      AND    stress_rating_id  = current_stress_rating_;
   --(+) 260722 GS0C130869 M-MRO-009 (Bug ID : 28208)(FINISH) 

   CURSOR get_value_total(part_no_ VARCHAR2,serial_no_ VARCHAR2) IS
      SELECT oper_param, 
             value_total 
      FROM   serial_oper_log_tab 
      WHERE  part_no   = part_no_
      AND    serial_no = serial_no_;

   CURSOR get_maint_oper_params(part_no_ VARCHAR2, serial_no_ VARCHAR2) IS
      SELECT Maint_Event_API.Get_Task_Oper_Param(part_no, serial_no, event_no, maint_event_type_db, 1)      oper_param1,
             Maint_Event_API.Get_Task_Remaining_Value(part_no, serial_no, event_no, maint_event_type_db, 1) remaining_value1,
             Maint_Event_API.Get_Task_Oper_Param(part_no, serial_no, event_no, maint_event_type_db, 2)      oper_param2,
             Maint_Event_API.Get_Task_Remaining_Value(part_no, serial_no, event_no, maint_event_type_db, 2) remaining_value2,
             Maint_Event_API.Get_Task_Oper_Param(part_no, serial_no, event_no, maint_event_type_db, 3)      oper_param3,
             Maint_Event_API.Get_Task_Remaining_Value(part_no, serial_no, event_no, maint_event_type_db, 3) remaining_value3
      FROM   maint_event2
      WHERE  part_no             = part_no_
      AND    serial_no           = serial_no_
      AND    maint_event_type_db = '1'
      AND    event_code          = 'OVERHAUL'
      FETCH  FIRST 1 ROW ONLY;
   --(+) 260722 GS0C130869 M-MRO-009 (Bug ID : 28208)(START)      
   -- Fetch part revision and template information from the serial structure.
   -- The part revision is required to accurately retrieve the life limit
   -- definition for the serialized part.   
   CURSOR get_serial_str_info(part_no_   VARCHAR2, serial_no_ VARCHAR2) IS
      SELECT part_rev,
             top_part_no,
             top_part_rev
      FROM  Vim_Serial_Structure_TAB
      WHERE part_no   = part_no_
      AND   serial_no = serial_no_;
 
   --(+) 260722 GS0C130869 M-MRO-009 (Bug ID : 28208)(FINISH)      
   
   $END
BEGIN
   $IF Component_Vim_SYS.INSTALLED $THEN
      
      --(+) 260722 GS0C130869 M-MRO-009 (Bug ID : 28208)(START) 
      -- Fetch the part revision and template information from the serial structure.
      -- These values are required to uniquely identify the applicable life limit
      -- definition and prevent duplicate records when a part has multiple revisions.
      OPEN  get_serial_str_info(part_no_, serial_no_);
      FETCH get_serial_str_info INTO part_rev_, top_part_, top_part_rev_;
      CLOSE get_serial_str_info;
      --(+) 260722 GS0C130869 M-MRO-009 (Bug ID : 28208)(FINISH) 

      OPEN  get_stress_ratings(part_no_,serial_no_);
      FETCH get_stress_ratings INTO life_limited_,current_stress_rating_;
      CLOSE get_stress_ratings;

      IF life_limited_ = 'Life Limited' THEN
      
      --(+) 260722 GS0C130869 M-MRO-009 (Bug ID : 28208)(START) 
      -- Pass the part revision and template information to fetch the
      -- corresponding life limit definition. This avoids duplicate
      -- Remaining Life values caused by multiple revisions of the same part.
      FOR life_ IN get_life_limit_values( part_no_, part_rev_, top_part_, top_part_rev_, current_stress_rating_) LOOP
      --(+) 260722 GS0C130869 M-MRO-009 (Bug ID : 28208)(FINISH) 
            FOR val_ IN get_value_total(part_no_,serial_no_) LOOP
               IF life_.oper_param = val_.oper_param THEN
                  calc_value_  := life_.life_limit - val_.value_total;
                  result_      := to_char(result_) || life_.oper_param ||': '||to_char(calc_value_)||' ';
               END IF;
            END LOOP;
         END LOOP;
         RETURN result_;

      ELSIF life_limited_ = 'Not Life Limited' THEN
         OPEN  get_maint_oper_params(part_no_,serial_no_);
         FETCH get_maint_oper_params INTO oper_param_1_,remaining_value_1_,oper_param_2_,remaining_value_2_,oper_param_3_,remaining_value_3_;
         CLOSE get_maint_oper_params;
         IF oper_param_1_ IS NOT NULL THEN 
            result_ := oper_param_1_||': '||remaining_value_1_||' ';
            IF oper_param_2_ IS NOT NULL THEN
               result_ := result_||oper_param_2_||': '||remaining_value_2_||' ';
               IF oper_param_2_ IS NOT NULL THEN
                  result_ := result_||oper_param_3_||': '||remaining_value_3_||' ';
               END IF;
            END IF;
         END IF;
         RETURN result_;
      ELSE
         RETURN NULL;
      END IF;
   $ELSE
      RETURN NULL;
   $END
END C_Get_Remaining_Life;
-- (+) 240327  TecKiranK M-MRO-098 (FINISH)
--(+) 260722 GS0C130869 M-MRO-009 (Bug ID : 28208)(FINISH) 

-- (+) 240628 TecGovinT M-MRO-010 (START)
PROCEDURE C_Modify(
   interim_header_id_ IN     VARCHAR2,
   attr_              IN OUT VARCHAR2,
   action_            IN     VARCHAR2)
IS
   objid_      VARCHAR2(100);
   objversion_ VARCHAR2(100);

   oldrec_     interim_demand_head_tab%ROWTYPE;
   newrec_     interim_demand_head_tab%ROWTYPE;
   indrec_     Indicator_Rec;
BEGIN

   IF (action_ = 'CHECK') THEN
      oldrec_ := Get_Object_By_Keys___(interim_header_id_);
      newrec_ := oldrec_;
      Unpack___(newrec_, indrec_, attr_);
      Check_Update___(oldrec_, newrec_, indrec_, attr_);
   ELSIF (action_ = 'DO') THEN
      oldrec_ := Lock_By_Keys_Nowait___(interim_header_id_);
      newrec_ := oldrec_;
      Unpack___(newrec_, indrec_, attr_);
      Check_Update___(oldrec_, newrec_, indrec_, attr_);
      Update___(objid_, oldrec_, newrec_, attr_, objversion_, TRUE);
   END IF;
END C_Modify;
-- (+) 240628 TecGovinT M-MRO-010 (FINISH)


--(+) 250213 BK0C119713 M-MRO-048 (START)
FUNCTION C_Get_Tag_Tos(
   order_type_   IN  VARCHAR2,
   identity1_    IN  VARCHAR2,
   identity2_    IN  VARCHAR2,
   identity3_    IN  VARCHAR2,
   c_parent_cro_ IN  VARCHAR2 ) RETURN VARCHAR2
IS
   $IF Component_Chmgmt_SYS.INSTALLED AND Component_Mromfg_SYS.INSTALLED AND Component_Cmod_SYS.INSTALLED $THEN
      tag_tos_      mrb_disposition_tab.c_maint_code%TYPE;
      part_no_      interim_demand_head_tab.description%TYPE;
      c_identity1_  interim_order_supply_tab.identity1%TYPE;
      c_identity2_  interim_order_supply_tab.identity2%TYPE;
      c_identity3_  interim_order_supply_tab.identity3%TYPE;

      CURSOR Get_Top_Part_Tag_Tos_Wo IS
         SELECT ios.identity1, ios.identity2, ios.identity3
         FROM   interim_demand_head_tab  idh,
                interim_order_tab        io,
                interim_order_supply_tab ios
         WHERE  idh.interim_header_id                   = io.interim_header_id
         AND    idh.interim_header_id                   = ios.interim_header_id(+)
         AND    io.interim_order_no                     = ios.interim_order_no(+)
         AND    Shop_Ord_Code_API.Decode(io.order_code) = 'Assembly'
         AND    idh.identity1                           = identity1_

      CURSOR Get_Top_Part_Tag_Tos_Cro IS
         SELECT ios.identity1, ios.identity2, ios.identity3
         FROM   interim_demand_head_tab  idh,
                interim_order_tab        io,
                interim_order_supply_tab ios
         WHERE  idh.interim_header_id                   = io.interim_header_id
         AND    idh.interim_header_id                   = ios.interim_header_id(+)
         AND    io.interim_order_no                     = ios.interim_order_no(+)
         AND    Shop_Ord_Code_API.Decode(io.order_code) = 'Repair'
         AND    C_Order_Str_Wo_Cro_Util_API.Get_Tag_Tos(ios.identity1, ios.identity2, ios.identity3) IS NOT NULL
         AND    idh.identity1                           = identity1_;

      CURSOR Get_Parent_Part IS
         SELECT idh.top_part_no  
         FROM   interim_demand_head  idh,
                interim_order_tab    io,
                interim_order_supply_tab ios
         WHERE  idh.interim_header_id  = io.interim_header_id
         AND    idh.interim_header_id  = ios.interim_header_id(+)
         AND    io.interim_order_no    = ios.interim_order_no(+)
         AND    idh.identity1          = identity1_;

      CURSOR Get_Child_Part_Tag_Tos_Cro(c_part_no_ VARCHAR2) IS
         SELECT ios.identity1, ios.identity2, ios.identity3
         FROM   interim_demand_head      idh,
                interim_order_tab        io,
                interim_order_supply_tab ios
         WHERE  idh.interim_header_id                   = io.interim_header_id
         AND    idh.interim_header_id                   = ios.interim_header_id(+)
         AND    io.interim_order_no                     = ios.interim_order_no(+)
         AND    Shop_Ord_Code_API.Decode(io.order_code) = 'Assembly'
         AND    idh.serial_begin                        = C_Order_Str_Wo_Cro_Util_API.Get_Serial_No_For_SO(idh.interim_header_id, ios.interim_order_no, ios.identity1, ios.identity2, ios.identity3, io.order_code
         AND    idh.top_part_no                         = c_part_no_
         AND    idh.part_no                             = io.part_no
         AND    idh.c_parent_cro                        = c_parent_cro_;
   $END
BEGIN
   $IF Component_Chmgmt_SYS.INSTALLED AND Component_Mromfg_SYS.INSTALLED AND Component_Cmod_SYS.INSTALLED $THEN
      IF (order_type_ = 'WO') THEN 
         OPEN  Get_Top_Part_Tag_Tos_Wo;
         FETCH Get_Top_Part_Tag_Tos_Wo INTO c_identity1_, c_identity2_, c_identity3_;
         CLOSE Get_Top_Part_Tag_Tos_Wo;
         
      ELSIF (order_type_ = 'CRO') THEN 
         OPEN  Get_Top_Part_Tag_Tos_Cro;
         FETCH Get_Top_Part_Tag_Tos_Cro INTO c_identity1_, c_identity2_, c_identity3_;
         CLOSE Get_Top_Part_Tag_Tos_Cro;
         
         tag_tos_ := C_Order_Str_Wo_Cro_Util_API.Get_Tag_Tos(c_identity1_, c_identity2_, c_identity3_);
         
         IF (tag_tos_ IS NULL) THEN
            OPEN  Get_Parent_Part;
            FETCH Get_Parent_Part INTO part_no_;
            CLOSE Get_Parent_Part;

            OPEN  Get_Child_Part_Tag_Tos_Cro(part_no_);
            FETCH Get_Child_Part_Tag_Tos_Cro INTO c_identity1_, c_identity2_, c_identity3_;
            CLOSE Get_Child_Part_Tag_Tos_Cro;
         END IF;
      END IF;
      
      tag_tos_ := C_Order_Str_Wo_Cro_Util_API.Get_Tag_Tos(c_identity1_, c_identity2_, c_identity3_);
      
      RETURN tag_tos_;
   $ELSE
      RETURN NULL;
   $END
END C_Get_Tag_Tos;
--(+) 250213 BK0C119713 M-MRO-048 (FINISH)
FUNCTION C_Get_Cus_No(interim_header_id_ IN VARCHAR2) RETURN VARCHAR2
IS
   cus_no_      VARCHAR2(25);
   CURSOR c_get_cust_no IS
      SELECT  owning_customer_no 
      FROM  Interim_Demand_Head_tab 
      WHERE interim_header_id =interim_header_id_;
BEGIN
   OPEN  c_get_cust_no;
   FETCH c_get_cust_no INTO cus_no_;
   CLOSE c_get_cust_no;
   RETURN cus_no_;  
END C_Get_Cus_No;

FUNCTION C_Get_Cont_Dtls(interim_header_id_ IN VARCHAR2) RETURN VARCHAR2
IS
   contract_      VARCHAR2(5);
   CURSOR c_get_contract IS
      SELECT  contract 
      FROM  Interim_Demand_Head_tab 
      WHERE interim_header_id =interim_header_id_;
BEGIN
   OPEN  c_get_contract;
   FETCH c_get_contract INTO contract_;
   CLOSE c_get_contract;
   RETURN contract_;  
END C_Get_Cont_Dtls;

--(+) 250724 BR0C122032 M-MRO-010 (START)
FUNCTION C_Reason_For_Incl(interim_header_id_ IN VARCHAR2) RETURN NUMBER
   
IS
   
   rec_cnt_ NUMBER := 0;
   
   $IF Component_Wscope_SYS.INSTALLED $THEN
      CURSOR get_reason_for_incl IS 
         SELECT count(*) 
         FROM   Work_Ord_Manual_Comp_Tab  
         WHERE  wo_no IN (SELECT identity1 
                          FROM Interim_Demand_Head_Tab 
                          WHERE interim_header_id = interim_header_id_) 
         AND    c_reason_for_inc = 'From Presurvey';
   $END
   
BEGIN
   
   $IF Component_Wscope_SYS.INSTALLED $THEN
      OPEN  get_reason_for_incl;
      FETCH get_reason_for_incl INTO rec_cnt_;
      CLOSE get_reason_for_incl;

      RETURN rec_cnt_; 
   $ELSE
      RETURN rec_cnt_;
   $END
   
END C_Reason_For_Incl;
--(+) 250724 BR0C122032 M-MRO-010 (FINISH)

--(+) 251231 HT0C130865 M-MRO-264(START)
FUNCTION C_Check_Work_Completion(
   c_interim_id_    IN VARCHAR2,
   c_work_order_no_ IN VARCHAR2) RETURN NUMBER 
IS
   
   $IF Component_Wo_Sys.INSTALLED $THEN 
      c_get_state_         active_work_order_tab.wo_status_id%TYPE;
   $END
   c_check_status_  NUMBER := 0;

BEGIN
   
   $IF Component_Wo_Sys.INSTALLED $THEN 
      c_get_state_ :=  Active_Separate_API.Get_Objstate(c_work_order_no_); 

      IF c_get_state_ = 'WORKDONE' THEN
         c_check_status_ := 1;
      END IF;
   $END
   
   RETURN c_check_status_;
   
END C_Check_Work_Completion;
--(+) 251231 HT0C130865 M-MRO-264(FINISH)

--(+/-) 260408 BR0C130841 M-MRO-048 (START)
PROCEDURE C_Camro_Cro_Cost_Details_
IS
   cattr_ VARCHAR2(32000);
   
   CURSOR c_interim_rec IS 
      SELECT interim_header_id, 
             interim_head_type, 
             identity1, 
             contract 
      FROM   Interim_Demand_Head_Tab
      WHERE  identity1 IS NOT NULL
      AND    c_cost_upd_after_spmt_crea = 'FALSE'
      AND    interim_head_type IN ('MRO', 'CRO');
      
BEGIN
   
   
   FOR crec_ IN c_interim_rec LOOP 
      
      $IF Component_Cmod_SYS.INSTALLED $THEN
      
         C_Camro_Cro_Cost_Details_API.Update_Camro_Cro_Cost_Details(crec_.interim_header_id,
                                                                    crec_.interim_head_type,
                                                                    crec_.identity1,
                                                                    crec_.contract);
   
      $ELSE
         NULL;
      $END
      
      Client_SYS.Clear_Attr(cattr_);
      Client_SYS.Add_To_Attr('C_COSTS_LAST_UPDATED', sysdate, cattr_);
      
      IF crec_.interim_header_id IS NOT NULL THEN 
         
         Interim_Demand_Head_API.C_Modify(crec_.interim_header_id, cattr_, 'DO');
      
      END IF;
         
END C_Camro_Cro_Cost_Details_;
--(+/-) 260408 BR0C130841 M-MRO-048 (FINISH)
