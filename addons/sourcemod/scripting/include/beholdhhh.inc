#if defined _beholdhhh_included_
  #endinput
#endif
#define _beholdhhh_included_

#define LIB_BEHOLDHHH "beholdhhh"

/**
 * Turns a client into the Horseless Headless Horsemann.
 *
 * @param iClient			Index of the client.
 * @param iHealth			The client's health, leave as 0 or below to use the convar health value.
 * @return Whether the client was turned into the Horseless Headless Horsemann.
 */
native bool BeholdHHH_Create(int iClient, int iHealth = 0);

/**
 * Removes the Horseless Headless Horsemann transformation from a client.
 *
 * @param iClient			Index of the client.
 * @return Whether the client was the Horseless Headless Horsemann.
 */
native bool BeholdHHH_Remove(int iClient);

/**
 * Whether the client is the Horseless Headless Horsemann.
 */
native bool BeholdHHH_IsBoss(int iClient);

public SharedPlugin __pl_beholdhhh = 
{
	name = LIB_BEHOLDHHH,
	file = LIB_BEHOLDHHH ... ".smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_beholdhhh_SetNTVOptional()
{
	MarkNativeAsOptional("BeholdHHH_Create");
	MarkNativeAsOptional("BeholdHHH_Remove");
	MarkNativeAsOptional("BeholdHHH_IsBoss");
}
#endif