
--Credit to Vuthakral for barnacle animations
wOS.DynaBase:RegisterSource({
	Name = "Vuthakral's Extended Player Animations",
	Type =  WOS_DYNABASE.EXTENSION,
	Male = "models/xdreanims/m_anm_slot_042.mdl",
	Female = "models/xdreanims/f_anm_slot_042.mdl",
	Zombie = "models/xdreanims/m_anm_slot_042.mdl",
})
wOS.DynaBase:RegisterSource({
	Name = "NEXUS WMV Pill Pack",
	Type = WOS_DYNABASE.EXTENSION,
	Male = "models/player/wiltos/wmvdeathanims.mdl",
	Female = "models/player/wiltos/wmvdeathanims.mdl",
	Zombie = "models/player/wiltos/wmvdeathanims.mdl",
})

hook.Add( "PreLoadAnimations", "wmvDynaBaseRegisterVuthExtensions", function( gender )
	if gender == WOS_DYNABASE.MALE then
		IncludeModel( "models/xdreanims/m_anm_slot_042.mdl" )
		IncludeModel( "models/player/wiltos/wmvdeathanims.mdl" )
	elseif gender == WOS_DYNABASE.FEMALE then
		IncludeModel( "models/xdreanims/f_anm_slot_042.mdl" )
		IncludeModel( "models/player/wiltos/wmvdeathanims.mdl" )
	elseif gender == WOS_DYNABASE.ZOMBIE then
		IncludeModel( "models/xdreanims/m_anm_slot_042.mdl" )
		IncludeModel( "models/player/wiltos/wmvdeathanims.mdl" )
	end
end )

hook.Add( "InitLoadAnimations", "wmvDynaBaseLoadVuthExtensions", function()
	wOS.DynaBase:RegisterSource({
		Name = "Vuthakral's Extended Player Animations",
		Type =  WOS_DYNABASE.EXTENSION,
		Male = "models/xdreanims/m_anm_slot_042.mdl",
		Female = "models/xdreanims/f_anm_slot_042.mdl",
		Zombie = "models/xdreanims/m_anm_slot_042.mdl",
	})
	wOS.DynaBase:RegisterSource({
		Name = "NEXUS WMV Pill Pack",
		Type = WOS_DYNABASE.EXTENSION,
		Male = "models/player/wiltos/wmvdeathanims.mdl",
		Female = "models/player/wiltos/wmvdeathanims.mdl",
		Zombie = "models/player/wiltos/wmvdeathanims.mdl",
	})
end )