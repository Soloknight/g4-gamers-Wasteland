// ******************************************************************************************
// * This project is licensed under the GNU Affero GPL v3. Copyright © 2014 A3Wasteland.com *
// ******************************************************************************************
//	@file Name: processGroupInvite.sqf
//	@file Author: AgentRev
//  @file Modified by Munch to handle Indy group changes and modify territory ownerships, if any
//  Note: pvar_processGroupInvite = ["accept", _playerUID, _oldGroup, _newGroup]

private ["_type", "_sender", "_receiver", "_invite", "_senderUID", "_receiverUID"];


diag_log "{INFO] processGroupInvite invoked with _this='%1'",_this];

_type = [_this, 0, "", [""]] call BIS_fnc_param;

switch (_type) do
{
	case "send":
	{
		_sender = [_this, 1, objNull, [objNull]] call BIS_fnc_param;
		_receiver = [_this, 2, objNull, [objNull]] call BIS_fnc_param;

		if (isPlayer _sender && isPlayer _receiver && {count units _receiver == 1}) then
		{
			_invite = [getPlayerUID _sender, getPlayerUID _receiver];

			// Clear any previous identical invite
			{
				if (_x isEqualTo _invite) then
				{
					currentInvites set [_forEachIndex, -1];
				};
			} forEach currentInvites;

			currentInvites = currentInvites - [-1];
			currentInvites pushBack _invite;
			publicVariable "currentInvites";

			pvar_groupNotify = ["invite", _sender];
			(owner _receiver) publicVariableClient "pvar_groupNotify";
		};
	};
	case "accept":
	{
		_receiverUID = [_this, 1, "", [""]] call BIS_fnc_param;
		_oldGroup =  [_this, 2, grpNull, [""]] call BIS_fnc_param;
		_newGroup =  [_this, 3, grpNull, [""]] call BIS_fnc_param;
		
		diag_log format ["[INFO] processGroupInvite handling 'accept' by uid %1 from group %1 into group %2", _receiverUID, _oldGroup, _newGroup];
		
		// Clear any invites sent from or to him
		{
			if (_receiverUID in _x) then
			{
				currentInvites set [_forEachIndex, -1];
			};
		} forEach currentInvites;

		currentInvites = currentInvites - [-1];
		publicVariable "currentInvites";
		
		// Handling for independents
		if (!(side _newGroup) in [BLUFOR,OPFOR]) then {
			// process territories
			
			// the territories currently held by the group
			_newTerritories = _newGroup getVariable ["currentTerritories", []];
			if (count _newTerritories > 0) then {
				diag_log format ["[INFO] processGroupInvite newGroup  %1 has currentTerritories='%2'", _newGroup, _newTerritories];
			};

			_oldTerritories = _oldGroup getVariable ["currentTerritories", []];
			if (count _oldTerritories > 0) then {
				// the invitee brought some territories with them
				diag_log format ["[INFO] processGroupInvite uid %1 has oldTerritories='%2'", _receiverUID, _oldTerritories];
				
				{ _newTerritories pushBack _x;} forEach _oldTerritories;
				
				diag_log format ["[INFO] processGroupInvite group %1 territories updated to '%2'", _newGroup, _newTerritories];
				
				_newGroup setVariable ["currentTerritories", _newTerritories, true];

				// call covnertTerritoryOwner to update territory group memberships, save the territory, 
				[_newTerritories, _newGroup] call convertTerritoryOwner;

			};

			// re-broadcast group territories owned to all of the group members
			["pvar_updateTerritoryMarkers", [_newGroup, [[_newTerritories], false, side _newGroup, true]]] call fn_publicVariableAll;

			if (!isNull _oldGroup) then
			{
				_oldGroup setVariable ["currentTerritories", [], true];
			};
			
		};
		
	};
	case "decline":
	{
		_senderUID = [_this, 1, "", [""]] call BIS_fnc_param;
		_receiverUID = [_this, 2, "", [""]] call BIS_fnc_param;
		_invite = [_senderUID, _receiverUID];

		// Clear the first matching invite
		{
			if (_x isEqualTo _invite) exitWith
			{
				currentInvites set [_forEachIndex, -1];
			};
		} forEach currentInvites;

		currentInvites = currentInvites - [-1];
		publicVariable "currentInvites";
	};
	case "kick":
	{
		// pvar_processGroupInvite = ["kick", _senderUID, _playerUID];
		_senderUID = [_this, 1, "", [""]] call BIS_fnc_param;
		_receiverUID = [_this, 2, "", [""]] call BIS_fnc_param;

		{ if (getPlayerUID _x == _receiverUID) exitWith { _target = _x } } forEach (call allPlayers);
		{ if (getPlayerUID _x == _senderUID) exitWith { _group = group _x } } forEach (call allPlayers);
		if (!(side _target in [OPFOR,BLUFOR])) then 
		{
			// indy player got kicked ... update his display to show he no longer has ownership of the group's territories
			["pvar_updateTerritoryMarkers",  [_target, [_group getVariable ["currentTerritories", []], false, side _target, false]]] call fn_publicVariableAll;
			
			// remove the player from the currentTerritoryDetails & persistence recs for this group
			_oldTerritories = _group getVariable ["currentTerritories", []];
			pvar_convertTerritoryOwner = [_oldTerritories, _group];
			publicVariableServer "pvar_convertTerritoryOwner";

			// call covnertTerritoryOwner to update territory group memberships, save the territory, 
			[_oldTerritories, _newGroup] call convertTerritoryOwner;
		};
	};
};
