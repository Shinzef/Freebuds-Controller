#pragma once

#ifdef BUILDING_OPENFREEBUDS_CORE
#define OPENFREEBUDS_API __declspec(dllexport)
#else
#define OPENFREEBUDS_API __declspec(dllimport)
#endif