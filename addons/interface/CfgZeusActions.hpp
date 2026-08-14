class ACE_ZeusActions {
    class GVAR(zeusRadio) {
        displayName = CSTRING(ModuleToggleRadio);
        class GVAR(zeusPower) {
            displayName = CSTRING(Power);
            statement = QUOTE([_target] call FUNC(power));
            condition = QUOTE(!(isNull _target) && {_target call FUNC(isCompatible)});
        };
    };
};
