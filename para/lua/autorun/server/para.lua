
if not SERVER then return end

AddCSLuaFile("autorun/client/para.lua")

PARA_MODEL = "models/parachute/chute.mdl" // Model path
PARA_ANCHORS = {
	{paravec = Vector(-120,30,0), ragdollbone = "ValveBiped.Bip01_L_Hand", ragdollvec = Vector(0,0,0), length = 200}, // 5 7 5 7
	{paravec = Vector(120,30,0), ragdollbone = "ValveBiped.Bip01_R_Hand", ragdollvec = Vector(0,0,0), length = 200},
	{paravec = Vector(-120,-30,0), ragdollbone = "ValveBiped.Bip01_L_Hand", ragdollvec = Vector(0,0,0), length = 200},
	{paravec = Vector(120,-30,0), ragdollbone = "ValveBiped.Bip01_R_Hand", ragdollvec = Vector(0,0,0), length = 200}
} // Anchor points between parachute, ragdoll, ragdollbone and its length

PARA_UNPARASOUND = Sound("npc/combine_soldier/zipline_clip1.wav")
PARA_PARASOUND = Sound("ambient/fire/mtov_flame2.wav")

local godwhilepara = CreateConVar( "para_godwhilepara", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE } )

/*
Player parachuting
*/
function DeployParachute(ply)
	if not IsValid(ply.pararag) then
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
			rag:Remove()
			error("An error occured when trying to create the ragdoll\nModel: "..ply:GetModel())
			return
		end
		
			rag:GetPhysicsObject():SetVelocity(plyvel)
		
		for _,wep in pairs(ply:GetWeapons()) do
			wep:SetNextPrimaryFire(CurTime() + 99999)
			wep:SetNextSecondaryFire(CurTime() + 99999)
		end
		ply:DrawViewModel(false)
		
		ply:SetMoveType(MOVETYPE_NOCLIP)
		ply:SetColor(Color(255,255,255,0))
		ply:SetRenderMode( 1 )
		
		umsg.Start("StartRagCam", ply)
			umsg.Entity(rag)
		umsg.End()
		
		ply.pararag = rag
		rag.paraply = ply
		
		ply:EmitSound(PARA_PARASOUND, 100, 100)
		
		// Spawn parachute n' shit
		local para = ents.Create("prop_physics")
			para:SetModel(PARA_MODEL)
			para:SetPos(ply:GetPos() + Vector(0,0,150))
			para:SetAngles(Angle(0,ply:GetAngles().y,0))
			para:Spawn()
			para:Activate()
		
		para.ropes = {}
		for _,ropetbl in pairs(PARA_ANCHORS) do
			local bone = rag:TranslateBoneToPhysBone( rag:LookupBone( ropetbl.ragdollbone ) )
			if bone != -1 then
				local ent, const = constraint.Rope(para, rag, 0, bone, ropetbl.paravec, ropetbl.ragdollvec, ropetbl.length, 0, 0, 2, "cable/rope", 0)
				table.insert(para.ropes, ent)
			end
		end
		ply.parapara = para
		para.paraply = ply
	end
end
concommand.Add("para_act", DeployParachute, ply)

function RemoveParachute(ply)
	if IsValid(ply.pararag) then
		ply:SetMoveType(MOVETYPE_WALK)
		ply:SetColor(Color(255,255,255,255))
		ply:SetRenderMode( 10 )
		ply:SetPos(ply.pararag:GetPos())
		ply:GetPhysicsObject():SetVelocity(ply.pararag:GetPhysicsObject():GetVelocity())
		
		if IsValid(ply.parapara) then
			for _,rope in pairs(ply.parapara.ropes) do
				rope:Remove() // Proper removal
			end
		end
		
		timer.Simple(1,function()
			for _,wep in pairs(ply:GetWeapons()) do
				wep:SetNextPrimaryFire(CurTime()+1)
				wep:SetNextSecondaryFire(CurTime()+1)
			end
		end)
		ply:DrawViewModel(true)
		
		ply.pararag:Remove()
		ply.parapara:Remove()
		
		umsg.Start("EndRagCam", ply)
		umsg.End()
		
		timer.Simple(.5,function()
			ply:EmitSound(PARA_UNPARASOUND, 100, 100)
		end)
	end
end

local speed = 700
hook.Add("Think", "Parachutes_think", function()
	for _,ply in pairs(player.GetAll()) do
		if IsValid(ply.pararag) then
			for _,wep in pairs(ply:GetWeapons()) do
				wep:SetNextPrimaryFire(CurTime() + 99999)
				wep:SetNextSecondaryFire(CurTime() + 99999)
			end
			
			local forward = ply:EyeAngles():Forward()
			forward.z = 0
			if ply:KeyDown(IN_FORWARD) then
				ply.pararag:GetPhysicsObject():ApplyForceCenter(forward * speed)
			elseif ply:KeyDown(IN_BACK) then
				ply.pararag:GetPhysicsObject():ApplyForceCenter(forward * speed * -1)
			end
		end
	end
end)

// If the ragdoll gets attacked, let the player take the damage!
hook.Add("EntityTakeDamage", "Parachutes_enttakedmg", function(targ, dmginfo)
	local attacker = dmginfo:GetAttacker()
	local inf = dmginfo:GetInflictor()
	local dmg = dmginfo:GetDamage()
	
	if not godwhilepara:GetBool() then
		if IsValid(targ.paraply) then
			print(attacker, inf)
			targ.paraply:TakeDamage( dmg, attacker, inf )
		end
	end
end)

// This is to fix the player's body which will otherwise spawn somewhere else
hook.Add("DoPlayerDeath", "Parachutes_doplydeath", function(ply, attacker, dmginfo)
	if IsValid(ply.pararag) then
		ply:SetPos(ply.pararag:GetPos())
	end
end)

/*
Remove parachute when mouseclick
*/
hook.Add("KeyPress", "Parachutes_keypress", function(ply, key)
	if key == IN_ATTACK and IsValid(ply.pararag) then
		RemoveParachute(ply)
	end
end)

/*
Disallow tools on parachute or ragdoll
*/
hook.Add("CanTool", "Parachutes_cantool", function(ply, tr, tool)
	if IsValid(tr.Entity) and (IsValid(tr.Entity.paraply) or tr.Entity.isparachute) then
		return false
	end
end)

/*
Disallow physgun on parachute or ragdoll
*/
hook.Add("PhysgunPickup", "Parachutes_physpick", function(ply, ent)
	if IsValid(ent.paraply) or ent.isparachute then
		return false
	end
end)

/*
Reset shit if he dies
*/
hook.Add("PlayerDeath", "Parachutes_plydead", function(ply)
	if IsValid(ply.pararag) then
		ply:SetMoveType(MOVETYPE_WALK)
		ply:SetColor(Color(255,255,255,255))
		ply:SetRenderMode( 10 )
		ply.pararag:Remove()
		if IsValid(ply.parapara) then
			ply.parapara:Remove()
		end
		umsg.Start("EndRagCam", ply)
		umsg.End()
	end
end)

/*
Reset shit if he disconnects
*/
hook.Add("PlayerDisconnected", "Parachutes_plydisc", function(ply)
	if IsValid(ply.pararag) then
		ply.pararag:Remove()
		ply.parapara:Remove()
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
	
	return ent:GetModel() != PARA_MODEL // Disallow parachuting parachutes.
end
function DeployParachute_ent(ply, ent, loc)
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
		para:SetModel(PARA_MODEL)
		para:SetPos( p )
		para:SetAngles(Angle(0,0,0))
		para:Spawn()
		para:Activate()
		para.isparachute = true
		
	
	para.ropes = {}
	for _,ropetbl in pairs(PARA_ANCHORS) do
		local ent, const = constraint.Rope(para, ent, 0, 0, ropetbl.paravec, localvec, ropetbl.length, 0, 0, 2, "cable/rope", 0)
		table.insert(para.ropes, ent)
	end
	
	ent.para = para
	para.ent = ent
	
	if IsValid(ent:GetPhysicsObject()) then
		ent.oldmass = ent:GetPhysicsObject():GetMass()
	end
	
	ent:GetPhysicsObject():SetMass( 20 ) // Mass needs to be low, otherwise the parachute does jackshit
	
	return true
end

function RemoveParachute_ent(ply, ent)
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
		rope:Remove() // Proper removal
	end
	
	e.para:Remove()
	
	if IsValid(ent:GetPhysicsObject()) then
		e:GetPhysicsObject():SetMass( e.oldmass or 10 )
	end
	
	return true
end

hook.Add("EntityRemoved", "Parachutes_entremoved", function(ent)
	if IsValid(ent.para) then
		ent.para:Remove()
	end
end)


