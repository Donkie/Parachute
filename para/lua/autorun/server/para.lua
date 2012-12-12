
if not SERVER then return end

AddCSLuaFile("autorun/client/para.lua")

parachute = {}
parachute.paramodel = "models/parachute/chute.mdl" // Model path
parachute.ropeanchors = {
	{paravec = Vector(-120,30,0), ragdollbone = "ValveBiped.Bip01_L_Hand", ragdollvec = Vector(0,0,0), length = 200},
	{paravec = Vector(120,30,0), ragdollbone = "ValveBiped.Bip01_R_Hand", ragdollvec = Vector(0,0,0), length = 200},
	{paravec = Vector(-120,-30,0), ragdollbone = "ValveBiped.Bip01_L_Hand", ragdollvec = Vector(0,0,0), length = 200},
	{paravec = Vector(120,-30,0), ragdollbone = "ValveBiped.Bip01_R_Hand", ragdollvec = Vector(0,0,0), length = 200}
} // Anchor points between parachute, ragdoll, ragdollbone and its length

parachute.unparasound = Sound("npc/combine_soldier/zipline_clip1.wav")
parachute.parasound = Sound("ambient/fire/mtov_flame2.wav")

local godwhilepara = CreateConVar( "para_godwhilepara", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE } )

/*
Player parachuting
*/
function parachute.DeployParachute(ply)
	if not IsValid(ply.parachuteragdoll) then
		// Spawn ragdoll n' shit
		local plyphys = ply:GetPhysicsObject()
		local plyvel = Vector(0,0,0)
		if plyphys:IsValid() then
			plyvel = plyphys:GetVelocity()
		end
		local rag = ents.Create("prop_ragdoll")
			rag:SetModel(ply:GetModel())
			rag:SetPos(ply:GetPos())
			rag:SetAngles(Angle(90,ply:GetAngles().y,0))
			rag:Spawn()
			rag:Activate()
		
		if not IsValid(rag:GetPhysicsObject()) then
			ply:PrintMessage(HUD_PRINTTALK, "An error occured! Please try change player model and try again!")
			SafeRemoveEntity(rag)
			return
		end
		
			rag:GetPhysicsObject():SetVelocity(plyvel)
		
		
		// Spawn parachute n' shit
		local para = ents.Create("prop_physics")
			para:SetModel(parachute.paramodel)
			para:SetPos(ply:GetPos() + Vector(0,0,150))
			para:SetAngles(Angle(0,ply:GetAngles().y,0))
			para:Spawn()
			para:Activate()
		
		para.ropes = {}
		for _,ropetbl in pairs(parachute.ropeanchors) do
			local bone = rag:TranslateBoneToPhysBone( rag:LookupBone( ropetbl.ragdollbone ) )
			if bone != -1 then
				local ent, const = constraint.Rope(para, rag, 0, bone, ropetbl.paravec, ropetbl.ragdollvec, ropetbl.length, 0, 0, 2, "cable/rope", 0)
				table.insert(para.ropes, ent)
			end
		end
		//No ropes created, fucked up physbones
		if #para.ropes == 0 then
			ply:PrintMessage(HUD_PRINTTALK, "An error occured! Please try change player model and try again!")
			SafeRemoveEntity(rag)
			SafeRemoveEntity(para)
			return
		end
		
		//Stop firing of weapons
		for _,wep in pairs(ply:GetWeapons()) do
			wep:SetNextPrimaryFire(CurTime() + 99999)
			wep:SetNextSecondaryFire(CurTime() + 99999)
		end
		//Dont draw viewmodel
		ply:DrawViewModel(false)
		
		//Set player to noclip and make him invisiblu
		ply:SetMoveType(MOVETYPE_NOCLIP)
		ply:SetColor(Color(255,255,255,0))
		ply:SetRenderMode( 1 )
		
		//Start 3dperson
		umsg.Start("StartRagCam", ply)
			umsg.Entity(rag)
		umsg.End()
		
		//Play sound
		ply:EmitSound(parachute.parasound, 100, 100)
		
		ply.parachuteragdoll = rag
		ply.parachute = para
		para.parachuteowner = ply
		rag.parachuteowner = ply
	end
end
concommand.Add("para_act", function(ply) parachute.DeployParachute(ply) end)

function parachute.RemoveParachute(ply)
	if IsValid(ply.parachuteragdoll) then
		ply:SetMoveType(MOVETYPE_WALK)
		ply:SetColor(Color(255,255,255,255))
		ply:SetRenderMode( 10 )
		ply:SetPos(ply.parachuteragdoll:GetPos())
		ply:GetPhysicsObject():SetVelocity(ply.parachuteragdoll:GetPhysicsObject():GetVelocity())
		
		if IsValid(ply.parachute) then
			for _,rope in pairs(ply.parachute.ropes) do
				SafeRemoveEntity(rope) // Proper removal
			end
		end
		
		timer.Simple(1,function()
			for _,wep in pairs(ply:GetWeapons()) do
				wep:SetNextPrimaryFire(CurTime()+1)
				wep:SetNextSecondaryFire(CurTime()+1)
			end
		end)
		ply:DrawViewModel(true)
		
		SafeRemoveEntity(ply.parachuteragdoll)
		SafeRemoveEntity(ply.parachute)
		
		umsg.Start("EndRagCam", ply)
		umsg.End()
		
		timer.Simple(.5,function()
			ply:EmitSound(parachute.unparasound, 100, 100)
		end)
	end
end

local speed = 700
hook.Add("Think", "Parachutes_think", function()
	for _,ply in pairs(player.GetAll()) do
		if IsValid(ply.parachuteragdoll) then
			for _,wep in pairs(ply:GetWeapons()) do
				wep:SetNextPrimaryFire(CurTime() + 99999)
				wep:SetNextSecondaryFire(CurTime() + 99999)
			end
			ply:DrawViewModel(false)
			
			local forward = ply:EyeAngles():Forward()
			forward.z = 0
			if ply:KeyDown(IN_FORWARD) then
				ply.parachuteragdoll:GetPhysicsObject():ApplyForceCenter(forward * speed)
			elseif ply:KeyDown(IN_BACK) then
				ply.parachuteragdoll:GetPhysicsObject():ApplyForceCenter(forward * speed * -1)
			end
		end
	end
end)

// If the ragdoll gets attacked, let the player take the damage!
hook.Add("EntityTakeDamage", "Parachutes_enttakedmg", function(targ, dmginfo)
	local attacker = dmginfo:GetAttacker()
	local inf = dmginfo:GetInflictor()
	
	if not godwhilepara:GetBool() then
		if IsValid(targ.parachuteowner) then
			print(attacker, inf)
			targ.parachuteowner:TakeDamage( dmginfo:GetDamage(), attacker, inf )
		end
	end
end)

// This is to fix the player's body which will otherwise spawn somewhere else
hook.Add("DoPlayerDeath", "Parachutes_doplydeath", function(ply, attacker, dmginfo)
	if IsValid(ply.parachuteragdoll) then
		ply:SetPos(ply.parachuteragdoll:GetPos())
	end
end)

/*
Remove parachute when mouseclick
*/
hook.Add("KeyPress", "Parachutes_keypress", function(ply, key)
	if key == IN_ATTACK and IsValid(ply.parachuteragdoll) then
		parachute.RemoveParachute(ply)
	end
end)

/*
Disallow tools on parachute or ragdoll
*/
hook.Add("CanTool", "Parachutes_cantool", function(ply, tr, tool)
	if IsValid(tr.Entity) and (IsValid(tr.Entity.parachuteowner) or tr.Entity.isparachute) then
		return false
	end
end)

/*
Disallow physgun on parachute or ragdoll
*/
hook.Add("PhysgunPickup", "Parachutes_physpick", function(ply, ent)
	if IsValid(ent.parachuteowner) or ent.isparachute then
		return false
	end
end)

/*
Reset shit if he dies
*/
hook.Add("PlayerDeath", "Parachutes_plydead", function(ply)
	if IsValid(ply.parachuteragdoll) then
		ply:SetMoveType(MOVETYPE_WALK)
		ply:SetColor(Color(255,255,255,255))
		ply:SetRenderMode( 10 )
		SafeRemoveEntity(ply.parachuteragdoll)
		SafeRemoveEntity(ply.parachute)
		umsg.Start("EndRagCam", ply)
		umsg.End()
	end
end)

/*
Reset shit if he disconnects
*/
hook.Add("PlayerDisconnected", "Parachutes_plydisc", function(ply)
	if IsValid(ply.parachuteragdoll) then
		SafeRemoveEntity(ply.parachuteragdoll)
		SafeRemoveEntity(ply.parachute)
	end
end)

// Since the player doesn't move when he's ragdolled, we override this to return the ragdolls position instead.
local meta = FindMetaTable("Entity")
if not BKP_ENTGETPOS then
	BKP_ENTGETPOS = meta.GetPos
end
function meta:GetPos()
	if IsValid(self.pararag) then
		return self.pararag:GetPos()
	end
	return BKP_ENTGETPOS(self)
end

/*
Prop parachuting
*/
// I KNOW, I AM USING PHYSGUNPICKUP, BUT ITS THE CLOSEST PROTECTION TO THIS
local function Allowed(ply, ent)
	if CPPI then // CPPI exists, woo
		return ent:CPPICanPhysgun(ply)
	end
	
	return ent:GetModel() != parachute.paramodel // Disallow parachuting parachutes.
end
function parachute.DeployParachute_ent(ply, ent, loc)
	if not Allowed(ply, ent) then return false end
	if IsValid(ent.para) then return end
	
	local localvec = Vector(0,0,0)
	if loc then
		localvec = loc
	end
	
	local min,max = ent:WorldSpaceAABB()
	local p = ent:GetPos()
	p.z = max.z + 150
	local para = ents.Create("prop_physics")
		para:SetModel(parachute.paramodel)
		para:SetPos( p )
		para:SetAngles(Angle(0,0,0))
		para:Spawn()
		para:Activate()
		para.isparachute = true
		
	
	para.ropes = {}
	for _,ropetbl in pairs(parachute.ropeanchors) do
		local ent, const = constraint.Rope(para, ent, 0, 0, ropetbl.paravec, localvec, ropetbl.length, 0, 0, 2, "cable/rope", 0)
		table.insert(para.ropes, ent)
	end
	
	ent.para = para
	para.ent = ent
	
	if IsValid(ent:GetPhysicsObject()) then
		ent.oldmass = ent:GetPhysicsObject():GetMass()
		ent:GetPhysicsObject():SetMass( 20 ) // Mass needs to be low, otherwise the parachute does jackshit
	end
	
	return true
end

function parachute.RemoveParachute_ent(ply, ent)
	if not Allowed(ply, ent) then return false end
	
	local e = nil
	local ispara = ent.isparachute or false
	if ispara then
		e = ent.ent
	else
		e = ent
	end
	
	if not IsValid(e.para) then return end
	
	for _,rope in pairs(e.para.ropes) do
		SafeRemoveEntity(rope) // Proper removal
	end
	
	SafeRemoveEntity(e.para)
	
	if IsValid(ent:GetPhysicsObject()) then
		e:GetPhysicsObject():SetMass( e.oldmass or 10 )
	end
	
	return true
end

hook.Add("EntityRemoved", "Parachutes_entremoved", function(ent)
	if IsValid(ent.para) then
		SafeRemoveEntity(ent.para)
	end
end)


