library DefilerGoo initializer onInit requires Table, TimerUtils 
    globals
        private real GOO_MOVEMENT_TICK = 0.02 //how often does the system check for caster's movement

        //internal temp variables
        private Table data
        private group tempGroup = CreateGroup()
        private real x
        private real y
        private integer index
        private integer endIndex
        private unit u

        //keys
        private integer GOO_X = 0
        private integer GOO_Y = 1
        private integer GOO_TIME = 2
        private integer GOO_EFFECT = 3
    endglobals

    public struct GooInstance
        private unit        defiler
        private real        damagePerTick
        private real        gooLifetime
        private real        gooPlacementRadius
        private string      gooModel

        private trigger     defilerDeath
        private trigger     gooDamageRegister
        private trigger     gooDamageUnregister
        private timer       defilerTrackMovement
        private timer       damageTimer
        private timer       abilityTimer
        private region      gooRegion
        private group       damageGroup
        private rect        damageRect

        private integer     gooAddIndex = -1
        private integer     gooRemovalIndex = 0
        private real        gooDuration = 0.00
        private boolean     gooAbilityDone = false

        private static method PeriodicMovement takes nothing returns nothing
            local thistype this = GetTimerData(GetExpiredTimer())
            set this.gooDuration = this.gooDuration + GOO_MOVEMENT_TICK

            if (not this.gooAbilityDone) then
                call this.periodicAddCell()
            endif
            
            if (this.gooAddIndex >= this.gooRemovalIndex) then
                call this.periodicRemoveCell()
            elseif (this.gooAbilityDone) then
                call this.destroy() //ability is done in this case, can be safely removed
            endif
        endmethod

        private static method RegisterTarget takes nothing returns nothing
            local thistype this = data.integer.get(GetTriggeringTrigger())
            set u = GetTriggerUnit()

            if u != this.defiler then 
                call GroupAddUnit(this.damageGroup, u)    
            endif
        endmethod

        private static method UnregisterTarget takes nothing returns nothing
            local thistype this = data.integer.get(GetTriggeringTrigger())

            call GroupRemoveUnit(this.damageGroup, GetTriggerUnit())
        endmethod

        private static method EndAbility takes nothing returns nothing
            local thistype this = data.integer.get(GetTriggeringTrigger())

            set this.gooAbilityDone = true
        endmethod

        private static method EndAbilityTimer takes nothing returns nothing
            local thistype this = GetTimerData(GetExpiredTimer())

            set this.gooAbilityDone = true
        endmethod

        private static method Damage takes nothing returns nothing
            local thistype this = GetTimerData(GetExpiredTimer())
            set index = 0
            set endIndex = BlzGroupGetSize(this.damageGroup)
            loop
                exitwhen index >= endIndex

                call UnitDamageTarget(this.defiler, BlzGroupUnitAt(this.damageGroup, index), this.damagePerTick, false, false, ATTACK_TYPE_PIERCE, DAMAGE_TYPE_ACID, WEAPON_TYPE_WHOKNOWS)

                set index = index + 1
            endloop
        endmethod

        public static method create takes unit defiler, real abilityDuration, real damagePerTick, real secondsPerTick, real gooLifetime, real gooDamageRadius, real gooPlacementRadius, string gooModel returns thistype
            local thistype this = thistype.allocate()

            set this.defiler = defiler
            set this.damagePerTick = damagePerTick
            set this.gooLifetime = gooLifetime
            set this.gooPlacementRadius = gooPlacementRadius
            set this.gooModel = gooModel
            set this.gooRegion = CreateRegion()
            set this.damageGroup = CreateGroup()
            set this.damageRect = Rect(-gooDamageRadius/2, -gooDamageRadius/2, gooDamageRadius/2, gooDamageRadius/2)

            set this.defilerTrackMovement = NewTimerEx(this)
            call TimerStart(this.defilerTrackMovement, GOO_MOVEMENT_TICK, true, function thistype.PeriodicMovement)

            set this.damageTimer = NewTimerEx(this)
            call TimerStart(this.damageTimer, secondsPerTick, true, function thistype.Damage)

            set this.abilityTimer = NewTimerEx(this)
            call TimerStart(this.abilityTimer, abilityDuration, false, function thistype.EndAbilityTimer)

            set this.gooDamageRegister = CreateTrigger()
            call data.integer.store(this.gooDamageRegister, this)
            call TriggerAddAction(this.gooDamageRegister, function thistype.RegisterTarget)
            call TriggerRegisterEnterRegion(this.gooDamageRegister, this.gooRegion, null)

            set this.gooDamageUnregister = CreateTrigger()
            call data.integer.store(this.gooDamageUnregister, this)
            call TriggerAddAction(this.gooDamageUnregister, function thistype.UnregisterTarget)
            call TriggerRegisterLeaveRegion(this.gooDamageUnregister, this.gooRegion, null)

            set this.defilerDeath = CreateTrigger()
            call data.integer.store(this.defilerDeath, this)
            call TriggerAddAction(this.defilerDeath, function thistype.EndAbility)
            call TriggerRegisterUnitEvent(this.defilerDeath, this.defiler, EVENT_UNIT_DEATH)

            return this
        endmethod

        public method destroy takes nothing returns nothing
            call data.integer.forget(gooDamageRegister)
            call data.integer.forget(gooDamageUnregister)
            call data.integer.forget(defilerDeath)

            call RemoveRegion(gooRegion)
            call DestroyTrigger(defilerDeath)
            call DestroyTrigger(gooDamageRegister)
            call DestroyTrigger(gooDamageUnregister)
            call PauseTimer(defilerTrackMovement)
            call ReleaseTimer(defilerTrackMovement)
            call PauseTimer(damageTimer)
            call ReleaseTimer(damageTimer)
            call PauseTimer(abilityTimer)
            call ReleaseTimer(abilityTimer)
            call DestroyGroup(damageGroup)
            call RemoveRect(damageRect)
            call data[this].flush()
        endmethod

        private method periodicAddCell takes nothing returns nothing
            set x = GetUnitX(this.defiler)
            set y = GetUnitY(this.defiler)

            if (this.gooAddIndex != -1) then
                //Note: modify this to use circular radius instead of just X and Y distances in case of large radius
                if ((RAbsBJ(data[this][this.gooAddIndex].real[GOO_X] - x) <= this.gooPlacementRadius) and (RAbsBJ(data[this][this.gooAddIndex].real[GOO_Y] - y) <= this.gooPlacementRadius)) then

                    set data[this][this.gooAddIndex].real[GOO_TIME] = this.gooDuration //reset duration 
                    return // caster hasn't moved, do nothing
                endif
            endif

            set this.gooAddIndex = this.gooAddIndex + 1
            set data.link(this).link(this.gooAddIndex).real[GOO_X] = x
            set data.link(this).link(this.gooAddIndex).real[GOO_Y] = y
            set data.link(this).link(this.gooAddIndex).real[GOO_TIME] = this.gooDuration
            set data.link(this).link(this.gooAddIndex).effect[GOO_EFFECT] = AddSpecialEffect(this.gooModel, x, y)

            call MoveRectTo(this.damageRect, x, y)
            call RegionAddRect(this.gooRegion, this.damageRect)
            call GroupEnumUnitsInRect(tempGroup, this.damageRect, null)
            // check if units that were on this tile are considered in region or not
            set index = 0
            set endIndex = BlzGroupGetSize(tempGroup)
            loop
                exitwhen index >= endIndex
                set u = BlzGroupUnitAt(tempGroup, index)

                if u != this.defiler then 
                    call GroupAddUnit(this.damageGroup, u)    
                endif

                set index = index + 1
            endloop
        endmethod

        private method periodicRemoveCell takes nothing returns nothing
            if (data[this][this.gooRemovalIndex].real[GOO_TIME] + this.gooLifetime > this.gooDuration) then
                return //do nothing, not time to remove this yet
            endif

            set x = data[this][this.gooRemovalIndex].real[GOO_X]
            set y = data[this][this.gooRemovalIndex].real[GOO_Y]
            call DestroyEffect(data[this][this.gooRemovalIndex].effect[GOO_EFFECT])
            call data[this][this.gooRemovalIndex].flush()
            set this.gooRemovalIndex = this.gooRemovalIndex + 1
            
            call MoveRectTo(this.damageRect, x, y)
            call RegionClearRect(this.gooRegion, this.damageRect)
            call GroupEnumUnitsInRect(tempGroup, this.damageRect, null)
            // check if units that were on this tile are still considered in region or not
            set index = 0
            set endIndex = BlzGroupGetSize(tempGroup)
            loop
                exitwhen index >= endIndex
                set u = BlzGroupUnitAt(tempGroup, index)

                call GroupRemoveUnit(this.damageGroup, u)
                
                set index = index + 1
            endloop
        endmethod
    endstruct

    private function onInit takes nothing returns nothing
        set data = Table.create()
    endfunction
endlibrary