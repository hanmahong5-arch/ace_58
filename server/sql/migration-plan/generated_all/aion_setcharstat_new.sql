-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharStat_new.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharstat_new(_character_id INTEGER, _h_p INTEGER, _m_p INTEGER, _d_p INTEGER, _s_t_r INTEGER, _v_i_t INTEGER, _a_g_i INTEGER, _d_e_x INTEGER, _k_n_o INTEGER, _w_i_l_l INTEGER, _physical_right INTEGER, _accuracy_right INTEGER, _critical_right INTEGER, _physical_left INTEGER, _accuracy_left INTEGER, _critical_left INTEGER, _attack_speed INTEGER, _move_speed INTEGER, _magical_boost INTEGER, _magical_accuracy INTEGER, _physical_defend INTEGER, _dodge INTEGER, _block INTEGER, _parry INTEGER, _magic_resist INTEGER, _fire_resist INTEGER, _air_resist INTEGER, _water_resist INTEGER, _earth_resist INTEGER, _magical_right INTEGER, _magical_left INTEGER, _base_h_p INTEGER, _base_m_p INTEGER, _base_d_p INTEGER, _base_s_t_r INTEGER, _base_v_i_t INTEGER, _base_a_g_i INTEGER, _base_d_e_x INTEGER, _base_k_n_o INTEGER, _base_w_i_l_l INTEGER, _base_physical_right INTEGER, _base_accuracy_right INTEGER, _base_critical_right INTEGER, _base_physical_left INTEGER, _base_accuracy_left INTEGER, _base_critical_left INTEGER, _base_attack_speed INTEGER, _base_move_speed INTEGER, _base_magical_boost INTEGER, _base_magical_accuracy INTEGER, _base_physical_defend INTEGER, _base_dodge INTEGER, _base_block INTEGER, _base_parry INTEGER, _base_magic_resist INTEGER, _base_fire_resist INTEGER, _base_air_resist INTEGER, _base_water_resist INTEGER, _base_earth_resist INTEGER, _base_magical_right INTEGER, _base_magical_left INTEGER, _casting_time_ratio DOUBLE PRECISION, _magical_critical_right INTEGER, _magical_critical_left INTEGER, _critical_reduce_rate INTEGER, _critical_reduce_rate INTEGER, _critical_damage_reduce INTEGER, _critical_damage_reduce INTEGER, _heal_skill_boost INTEGER, _heal_skill_boost INTEGER, _base_magical_critical_right INTEGER, _base_magical_critical_left INTEGER, _base_phy_critical_reduce_rate INTEGER, _base_mag_critical_reduce_rate INTEGER, _base_phy_critical_damage_reduce INTEGER, _base_mag_critical_damage_reduce INTEGER, _base_heal_skill_boost INTEGER, _base_mp_heal_skill_boost INTEGER, _magical_defend INTEGER, _magical_skill_boost_resist INTEGER, _base_magical_defend INTEGER, _base_magical_skill_boost_resist INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN






	select character_id from user_stat(updlock) where character_id = _character_id

	if @_rowcount = 0 

		insert into user_stat (character_id,HP,MP,DP,STR,VIT,AGI,DEX,KNO,WILL,

		PhysicalRight,AccuracyRight,CriticalRight,PhysicalLeft,AccuracyLeft,CriticalLeft,

		AttackSpeed,MoveSpeed,MagicalBoost,

		MagicalAccuracy,PhysicalDefend,Dodge,Block,Parry,MagicResist,FireResist,AirResist,WaterResist,EarthResist,MagicalRight,MagicalLeft,

		baseHP,baseMP,baseDP,baseSTR,baseVIT,baseAGI,baseDEX,baseKNO,baseWILL,  

		basePhysicalRight,baseAccuracyRight,baseCriticalRight,basePhysicalLeft,baseAccuracyLeft,baseCriticalLeft,

		baseAttackSpeed,baseMoveSpeed,baseMagicalBoost,

		baseMagicalAccuracy,basePhysicalDefend,baseDodge,baseBlock,baseParry,baseMagicResist,baseFireResist,baseAirResist,baseWaterResist,baseEarthResist,baseMagicalRight, baseMagicalLeft,

		castingTimeRatio, magicalCriticalRight, magicalCriticalLeft,	phyCriticalReduceRate, magCriticalReduceRate, magCriticalDamageReduce, phyCriticalDamageReduce, healSkillBoost,

		baseMagicalCriticalRight, baseMagicalCriticalLeft, basePhyCriticalReduceRate, baseMagCriticalReduceRate, basePhyCriticalDamageReduce, baseMagCriticalDamageReduce, baseHealSkillBoost

		, magicalDefend, magicalSkillBoostResist, baseMagicalDefend, baseMagicalSkillBoostResist, mpHealSkillBoost, baseMpHealSkillBoost

		)

		values (_character_id ,_h_p,_m_p,_d_p,_s_t_r,_v_i_t,_a_g_i,_d_e_x,_k_n_o,_w_i_l_l,

		_physical_right,_accuracy_right,_critical_right,_physical_left,_accuracy_left,_critical_left,

		_attack_speed,_move_speed,_magical_boost,

		_magical_accuracy,_physical_defend,_dodge,_block,_parry,_magic_resist,_fire_resist,_air_resist,_water_resist,_earth_resist,_magical_right, _magical_left,

		_base_h_p,_base_m_p,_base_d_p,_base_s_t_r,_base_v_i_t,_base_a_g_i,_base_d_e_x,_base_k_n_o,_base_w_i_l_l,

		_base_physical_right,_base_accuracy_right,_base_critical_right,

		_base_physical_left,_base_accuracy_left,_base_critical_left,_base_attack_speed,_base_move_speed,_base_magical_boost,

		_base_magical_accuracy,_base_physical_defend,_base_dodge,_base_block,_base_parry,_base_magic_resist,_base_fire_resist,_base_air_resist,_base_water_resist,_base_earth_resist,_base_magical_right,_base_magical_left,

		_casting_time_ratio, _magical_critical_right, _magical_critical_left,	_critical_reduce_rate, _critical_reduce_rate, _critical_damage_reduce, _critical_damage_reduce, _heal_skill_boost,

		_base_magical_critical_right, _base_magical_critical_left, _base_phy_critical_reduce_rate, _base_mag_critical_reduce_rate, _base_phy_critical_damage_reduce,_base_mag_critical_damage_reduce, _base_heal_skill_boost,

		_magical_defend, _magical_skill_boost_resist, _base_magical_defend, _base_magical_skill_boost_resist, _heal_skill_boost, _base_mp_heal_skill_boost

		)

	else

		update user_stat set 

		HP = _h_p,

		MP = _m_p,

		DP = _d_p,

		STR = _s_t_r,

		VIT = _v_i_t,

		AGI = _a_g_i,

		DEX = _d_e_x,

		KNO = _k_n_o,

		WILL = _w_i_l_l,

		PhysicalRight = _physical_right,

		AccuracyRight = _accuracy_right,

		CriticalRight = _critical_right,

		PhysicalLeft  = _physical_left,

		AccuracyLeft  = _accuracy_left,

		CriticalLeft  = _critical_left,

		AttackSpeed   = _attack_speed,

		MoveSpeed     = _move_speed,

		MagicalBoost  = _magical_boost,

		MagicalAccuracy= _magical_accuracy,

		PhysicalDefend= _physical_defend,

		Dodge= _dodge,

		Block= _block,

		Parry= _parry,

		MagicResist= _magic_resist,

		FireResist= _fire_resist,

		AirResist= _air_resist,

		WaterResist= _water_resist,

		EarthResist= _earth_resist,

		MagicalRight = _magical_right,

		MagicalLeft = _magical_left,

		baseHP = _base_h_p,

		baseMP = _base_m_p,

		baseDP = _base_d_p,

		baseSTR= _base_s_t_r,

		baseVIT= _base_v_i_t,

		baseAGI= _base_a_g_i,

		baseDEX= _base_d_e_x,

		baseKNO= _base_k_n_o,  

		baseWILL= _base_w_i_l_l,

		basePhysicalRight = _base_physical_right,

		baseAccuracyRight = _base_accuracy_right,

		baseCriticalRight = _base_critical_right,

		basePhysicalLeft  = _base_physical_left,

		baseAccuracyLeft  = _base_accuracy_left,

		baseCriticalLeft  = _base_critical_left,

		baseAttackSpeed   = _base_attack_speed,

		baseMoveSpeed     = _base_move_speed,

		baseMagicalBoost  = _base_magical_boost,

		baseMagicalAccuracy= _base_magical_accuracy,

		basePhysicalDefend= _base_physical_defend,

		baseDodge= _base_dodge,

		baseBlock= _base_block,

		baseParry= _base_parry,

		baseMagicResist= _base_magic_resist,

		baseFireResist= _base_fire_resist,

		baseAirResist= _base_air_resist,

		baseWaterResist= _base_water_resist,

		baseEarthResist= _base_earth_resist,

		baseMagicalRight = _base_magical_right, 

		baseMagicalLeft = _base_magical_left, 

		castingTimeRatio = _casting_time_ratio, 

		magicalCriticalRight = _magical_critical_right, 

		magicalCriticalLeft = _magical_critical_left, 

		phyCriticalReduceRate = _critical_reduce_rate, 

		magCriticalReduceRate = _critical_reduce_rate, 

		magCriticalDamageReduce = _critical_damage_reduce, 

		phyCriticalDamageReduce = _critical_damage_reduce, 

		healSkillBoost = _heal_skill_boost,

		mpHealSkillBoost = _heal_skill_boost,

		baseMagicalCriticalRight = _base_magical_critical_right, 

		baseMagicalCriticalLeft = _base_magical_critical_left, 

		basePhyCriticalReduceRate = _base_phy_critical_reduce_rate, 

		baseMagCriticalReduceRate = _base_mag_critical_reduce_rate, 

		basePhyCriticalDamageReduce = _base_phy_critical_damage_reduce,

		baseMagCriticalDamageReduce = _base_mag_critical_damage_reduce, 

		baseHealSkillBoost = _base_heal_skill_boost,

		baseMpHealSkillBoost = _base_mp_heal_skill_boost,

		magicalDefend = _magical_defend,

		magicalSkillBoostResist = _magical_skill_boost_resist,

		baseMagicalDefend = _base_magical_defend,

		baseMagicalSkillBoostResist = _base_magical_skill_boost_resist

 

		where character_id = _character_id


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharstat_new;
-- +goose StatementEnd
