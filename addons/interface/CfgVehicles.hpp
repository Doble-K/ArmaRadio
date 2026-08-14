#define RADIO_SELF_ACTIONS \
    class ACE_SelfActions { \
        class GVAR(open) { \
            displayName = CSTRING(DisplayName); \
            statement = QUOTE(_target call FUNC(open)); \
            condition = QUOTE(_target call FUNC(isCompatible) && {_target call FUNC(canOpen)}); \
        }; \
    };

class CfgVehicles {
    class LandVehicle;
    class Car: LandVehicle {
        RADIO_SELF_ACTIONS
    };
    class Tank: LandVehicle {
        RADIO_SELF_ACTIONS
    };
    class Air;
    class Helicopter: Air {
        RADIO_SELF_ACTIONS
    };
    class Plane: Air {
        RADIO_SELF_ACTIONS
    };
    class StaticObject;
    class Ship: StaticObject {
        RADIO_SELF_ACTIONS
    };

    class Items_base_F;
    class Land_FMradio_F: Items_base_F {
        class ACE_Actions {
            class ACE_MainActions {
                selection = "interaction_point";
                distance = 5;
                class GVAR(open) {
                    displayName = CSTRING(DisplayName);
                    statement = QUOTE(_target call FUNC(open));
                };
            };
        };
    };
};
