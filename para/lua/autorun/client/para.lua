
if not CLIENT then return end

usermessage.Hook("StartRagCam", function( um )
	local rag = um:ReadEntity()
	LocalPlayer().CurRagCamTarg = rag
end)

usermessage.Hook("EndRagCam", function( )
	LocalPlayer().CurRagCamTarg = nil
end)

local dist = 200
hook.Add("CalcView", "Parachutes_calcview", function( ply, pos, ang, fov )
	if IsValid( ply.CurRagCamTarg ) and ply:GetViewEntity() == ply then
		local rag = ply.CurRagCamTarg
		
		pos = rag:GetPos() - ply:GetAimVector()*dist
		ang = (rag:GetPos() - pos):Angle()
		
		local tbl = {}
		tbl.origin = pos
		tbl.angles = ang
		tbl.fov = fov
		return tbl
	end
end)

local backedup = false
local backedup2 = true
hook.Add("Think", "Parachutes_cl_think", function()
	if LocalPlayer():GetViewEntity():GetClass() == "gmod_cameraprop" then
		if IsValid( LocalPlayer():GetViewEntity():GetentTrack().CurRagCamTarg ) then // If the current camera target has a valid ragdoll
			if not backedup then
				LocalPlayer():GetViewEntity().Think = function() end // Remove its think so it don't keep overwriting our stuff
				backedup = true
				backedup2 = false
			end
			
			LocalPlayer():GetViewEntity():TrackEntity( LocalPlayer():GetViewEntity():GetentTrack().CurRagCamTarg, LocalPlayer():GetViewEntity():GetvecTrack() )
		else
			if not backedup2 then
				LocalPlayer():GetViewEntity().Think = function(self)
					self:TrackEntity( self:GetentTrack(), self:GetvecTrack() )
				end
				backedup2 = true
				backedup = false
			end
		end
	end
end)
