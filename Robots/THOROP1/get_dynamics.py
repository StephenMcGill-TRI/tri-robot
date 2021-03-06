#!/usr/bin/python
import sympy
import sympybotics

'''

Make sure you know if you are using waist or nowaist!
Edit in convert_*.lua and get_dynamics.py if needed

Run python get_dynamics.py
Run luajit convert_jacobian.lua > test_jacobian_nowaist.lua
Run luajit convert_fk.lua > test_fk_nowaist.lua

l_8z is the x frame end effector offset from torso, since it does not use the last DH in the definition, it seems

'''

# DH Definition from Lua codebase
'''
		.mDH(-PI/2, 0, q[0], 0)
		.mDH(PI/2, 0, PI/2+q[1], 0)
		.mDH(PI/2, 0, PI/2+q[2], upperArmLength)
		.mDH(PI/2, elbowOffsetX, q[3], 0)
		.mDH(-PI/2, -elbowOffsetX, -PI/2+q[4], lowerArmLength)
		.mDH(-PI/2, 0, q[5], 0)
		.mDH(PI/2, 0, q[6], 0)
		.mDH(-PI/2, 0, -PI/2, 0)
'''

# Add symbols
pi = sympy.pi
q = sympybotics.robotdef.q
upperArmLength, elbowOffsetX, lowerArmLength, shoulderOffsetY, shoulderOffsetZ = sympy.symbols('upperArmLength, elbowOffsetX, lowerArmLength, shoulderOffsetY, shoulderOffsetZ')

kind = '_nowaist'
dh_params_nowaist = [
	(-pi/2, 0, shoulderOffsetY, q),
	(pi/2, 0, 0, q+pi/2),
	(pi/2, 0, upperArmLength, q+pi/2),
	(pi/2, elbowOffsetX, 0, q),
	(-pi/2, -elbowOffsetX, lowerArmLength, q-pi/2),
	(-pi/2, 0, 0, q),
	(pi/2, 0, 0, q),
	(-pi/2, 0, 0, -pi/2)
]
dh_params = dh_params_nowaist

'''
kind = '_waist'
dh_params_waist = [
	(0, 0, shoulderOffsetZ, q), #yaw
	(-pi/2, 0, shoulderOffsetY, q),
	(pi/2, 0, 0, q+pi/2),
	(pi/2, 0, upperArmLength, q+pi/2),
	(pi/2, elbowOffsetX, 0, q),
	(-pi/2, -elbowOffsetX, lowerArmLength, q-pi/2),
	(-pi/2, 0, 0, q),
	(pi/2, 0, 0, q),
	(-pi/2, 0, 0, -pi/2)
]
dh_params = dh_params_waist
'''

'''
kind = '_rleg'
dh_params = [
(0, 0, 0, q+pi/2),
(pi/2, 0, 0, q+pi/2),
(pi/2, 0, 0, q+aThigh),
('0', -dThigh, 0, q-aTibia-aThigh),
('0', -dTibia, 0, q+aTibia),
(-pi/2, 0, 0, q),
]
'''


# We use the modified convention
print('Define the Robot')
rbtdef = sympybotics.RobotDef('THOR-OP 7DOF Arm', dh_params, dh_convention='modified')

print('Find the Dynamic parameters')
rbt = sympybotics.RobotDynCode(rbtdef, verbose=True)

#print('DH Parameters')
#print(dh_params)
#print('Forward kinematics @ -1')
#print(rbt.geo.T[-1])
#print('Forward kinematics @ -2')
#print(rbt.geo.T[-2])
#print('Jacobian @ -1')
#print(rbt.kin.J[-1])
#print('Jacobian @ -2')
#print(rbt.kin.J[-2])
#print(tau_str)
#rbt.dyn.baseparms

# Save stuff
f = open("fk"+kind+".txt", "w")
try:
	f.write(str(rbt.geo.T[-1]))
finally:
	f.close()

'''
# This is not useful
f = open("jacobian"+kind+".txt", "w")
try:
	f.write(str(rbt.kin.J[-1]))
finally:
	f.close()
'''

# This may include the end effect, as l_8x
# For the leg, do -1, not -2
f = open("jacobian_com"+kind+".txt", "w")
try:
	f.write(str(rbt.kin.Jc[-2]))
finally:
	f.close()

f = open("DH_Params"+kind+".txt", "w")
try:
	f.write('(alpha, a, d, theta)\n')
	f.write(str(dh_params))
finally:
	f.close()

dp = rbtdef.dynparms()
f = open("Dynamic_Barycentric_Parameters"+kind+".txt", "w")
try:
	f.write(str(dp))
finally:
	f.close()

print('Generate the C code for the inertia matrix')
#print(rbt.M_code)
m_str = sympybotics.robotcodegen.robot_code_to_func('C', rbt.M_code, 'm_out', 'm', rbtdef)
f = open("inertia"+kind+".txt", "w")
try:
    f.write(m_str)
finally:
    f.close()

print('Generate the C code for the inverse dynamics')
tau_str = sympybotics.robotcodegen.robot_code_to_func('C', rbt.invdyn_code, 'tau_out', 'tau', rbtdef)

f = open("inverse_dynamics"+kind+".txt", "w")
try:
    f.write(tau_str)
finally:
    f.close()

'''
print('Find the base parameters for dynamics')
rbt.calc_base_parms(verbose=True)
f = open("baseparms"+kind+".txt", "w")
try:
	f.write(str(rbt.dyn.baseparms))
finally:
	f.close()

'''
