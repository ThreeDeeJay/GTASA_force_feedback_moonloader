-- local Aim =		require "lib.Aim"
local KEY =		require"lib.vkeys"
local memory =	require"memory"
local ffb = 	require"ffb"
local Vector =	require"lib.vector3d"
local Pointer = 0
local Bytes1 = {137, 142, 156, 4, 0, 0}
local Bytes2 = {137, 134, 156, 4, 0, 0}
local Bytes3 = {137, 142, 148, 4, 0 ,0}
local Bytes4 = {0x7A, 0x06}
local Bytes5 = {0x7A ,0x08}
local NOP = 144
local Pointer1 = 0x06ADC0C
local CameraStopPtr = 0x0525A27
local SpeedTurnMult = 0x06B2A24
local Pointer2 = 0x06ADB80
local TurnAddress = 0x06ADD22
local ACTIVE = true 
local Enabled = false
local LastX = 0 
local LastY = 0
local MaxTurnAngle = 0.9090909090909091
local MaxTurnAngle = 1.1090909090909091
local MaxTurnAngle = 1.4090909090909091
local MaxFFBForce = 9000
local MaxThrottle = 1.4

local MaxBrake = 1.0
local SteerMult = 0.852
local CamHorizontal = 0xB6F258
-- local SteerMult = 1
local ConsoleCreated = false
local DontFFB = false

function Lerp( delta, from, to )
	if ( delta > 1 ) then return to end
	if ( delta < 0 ) then return from end
	return from + ( to - from ) * delta
end
function Lerp( a,  b,  x)
	return a + x * (b - a)
end
function GetCarVelocity(vehicle)
	local x = memory.getfloat(getCarPointer(vehicle)+68,true)
	local y = memory.getfloat(getCarPointer(vehicle)+72,true)
	local z = memory.getfloat(getCarPointer(vehicle)+76,true)
	return x,y,z
end
function getDistance(x1,y1,z1,x2,y2,z2)
	return math.sqrt((x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2) + (z1 - z2)*(z1 - z2))
end

function normalizeAngle(angle)
    local newAngle = angle
    while (newAngle <= -180) do newAngle = newAngle + 360 end
    while (newAngle > 180) do newAngle = newAngle - 360 end
    return newAngle
end

function CalcAngle(src, dst)
    angles = Vector(0,0,0)
    angles.x = (-math.atan2(dst.x - src.x, dst.y - src.y)) / math.pi * 180.0 + 90.0
    angles.y = (-math.atan2(dst.z - src.z, getDistance(src.x, src.y, src.z, dst.x, dst.y, dst.z))) * 180.0 / math.pi
    angles.z = 0.0
    return angles
end
function GetVehicleRotation(vehicle)
	local qx, qy, qz, qw = getVehicleQuaternion(vehicle)
	rx = math.asin(2*qy*qz-2*qx*qw)
	ry = -math.atan2(qx*qz+qy*qw,0.5-qx*qx-qy*qy)
	rz = -math.atan2(qx*qy+qz*qw,0.5-qx*qx-qz*qz)
	return rx,ry,rz
end

function Hacc(bool)
	if bool then
		for i = 1,6 do 
			memory.write(Pointer1+i-1, NOP,1, true)
			memory.write(Pointer2+i-1, NOP,1, true)
			memory.write(TurnAddress+i-1, NOP,1, true)
		end
		for i = 1,2 do
			memory.write(CameraStopPtr+i-1, NOP,1, true)
			memory.write(SpeedTurnMult+i-1, NOP,1, true)
		end
		
	else 
	
		for i = 1,2 do
			memory.write(CameraStopPtr+i-1, Bytes4[i],1, true)
			memory.write(SpeedTurnMult+i-1, Bytes5[i],1, true)
		end
		for i = 1,6 do 
			memory.write(Pointer1+i-1, Bytes1[i],1, true)
			memory.write(Pointer2+i-1, Bytes2[i],1, true)
			memory.write(TurnAddress+i-1, Bytes3[i],1, true)
		end
	end
end
	
function LowerNearZero(i,limit)
	local num = i
	if num < limit then
		num = num / (limit-num)
		num = Lerp(num,i,i/limit)
		return num
	end
	return i
end

function main()
	while not isOpcodesAvailable() do wait(100) end
	
	-- ffb.SpawnConsole()
	while ACTIVE do  
		wait(0)
		if Enabled then 
			if isCharInAnyCar(PLAYER_PED) then
				local car = storeCarCharIsInNoSave(PLAYER_PED)
				local axis = ffb.GetData()
				local Ang = 0
				local Forward = 0
				local Backward = 0
				-- for k,v in pairs(axis) do print(k,v) end
				if axis and axis[0] then
				
					Ang = ((2^15 - axis[3]) / 2^15) * MaxTurnAngle
					-- if Ang < 0.01 then Ang =
					Ang = -Ang
					Forward = ((2^16-axis[4]) / 2^16) * MaxThrottle
					
					if Forward < 0.001 then Forward = 0 end
					Forward = Forward * MaxThrottle
					Backward = ((2^16-axis[2]) / 2^16) * MaxBrake
					-- printStringNow(Backward,100)
					if Backward < 0.001 then Backward = 0 end
					Backward = Backward * MaxBrake
				end
				-- print(Ang,Forward,Backward)
				local WheelTurn = getCarPointer(car)+1172
				local ForwardPedal = getCarPointer(car)+1180
				ffb.AcquireDevice()
				
				
				-- Calculate CounterSteer angle
				
				local p1 = Vector(getCarCoordinates(car))
				local vel = Vector(GetCarVelocity(car))
				local A2 = CalcAngle(p1,p1-vel)
				local Rot = Vector(GetVehicleRotation(car))
				
				local AimAng = normalizeAngle(A2.x-normalizeAngle(-90-math.deg(Rot.z)))
				-- print(vel:length())
				
				if math.abs(AimAng) > 120 or vel:length() < 0.05 then
					
					DontFFB = true
					else DontFFB = false 
					memory.setfloat(CamHorizontal,math.rad(A2.x),true)
				end
				
				local MovingAngleVelocity = math.abs(AimAng)

				AimAng = math.rad(AimAng)
				-- AimAng = AimAng * SteerMult
				
				if AimAng > MaxTurnAngle then AimAng = MaxTurnAngle end
				if AimAng < -MaxTurnAngle then AimAng = -MaxTurnAngle end
				
				local FFBSteerAngle = math.deg(-Ang)
				local FFBWheelAngle = math.deg(AimAng)

				-- renderDrawBox(900- math.floor(FFBSteerAngle), 300, 50,50, 0xFFFF0000)
				-- renderDrawBox(900- math.floor(FFBWheelAngle), 350, 50,50, 0xFFFF0000)
				if DontFFB then FFBSteerAngle = FFBWheelAngle end
				local FFBVal = (FFBSteerAngle-FFBWheelAngle)*980
				if FFBVal > MaxFFBForce then FFBVal = MaxFFBForce end
				if FFBVal < -MaxFFBForce then FFBVal = -MaxFFBForce end
				FFBVal = math.floor(-FFBVal)
				
				
				ffb.SetFFB(FFBVal)
				

				-- Limit movement near 0
				-- print(Ang)
				-- LowerNearZero(Ang,0.02)
				
				-- memory.setfloat(WheelTurn, -Ang *  0.5, true)
				memory.setfloat(WheelTurn, -Ang, true)

				if Forward > Backward then
					memory.setfloat(ForwardPedal, Forward, true)
					memory.write(0x0B73478, 255,1, true)
					memory.write(0x0B73474, 0,1, true)
					else
					memory.setfloat(ForwardPedal, -Backward, true)
					memory.write(0x0B73478, 0,1, true)
				end
				if Backward > 0.001 then memory.write(0x0B73474, 255,1, true) end
				-- else print"yoo"
			end
			
		end
		if isKeyDown(KEY.VK_MENU) and wasKeyPressed(KEY.VK_F6) then 
			Enabled = not Enabled
			-- if not ConsoleCreated then ffb.SpawnConsole() ConsoleCreated = true end 
			if Enabled then ffb.FreeDirectInput() ffb.Init()   else ffb.FreeDirectInput() end  
			-- if Enabled then  end
			Hacc(Enabled)
			print("Wheel+Pedals+FFB now: "..tostring(Enabled))
		end
	end
end
