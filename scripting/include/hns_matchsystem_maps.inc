#if defined _hns_matchsystem_maps_included
	#endinput
#endif
#define _hns_matchsystem_maps_included

/**
* Returns map module init state.
*
* @return		1 if map module is available, otherwise 0
*/
native hnsmatch_maps_init();

/**
* Returns whether current map is knife map.
*
* @return		true if knife map, otherwise false
*/
native bool:hnsmatch_maps_is_knife();

/**
* Returns whether current map is boost map.
*
* @return		true if boost map, otherwise false
*/
native bool:hnsmatch_maps_is_boost();

/**
* Returns whether current map is skill map.
*
* @return		true if skill map, otherwise false
*/
native bool:hnsmatch_maps_is_skill();

/**
* Loads map-based settings (roundtime/freezetime/flash/smoke).
*
* @return		true if settings were loaded, otherwise false
*/
native bool:hnsmatch_maps_load_settings();
