library EyeBeam initializer onInit requires Table, TimerUtils
    globals
        private real BEAM_MOVEMENT_TICK = 0.02 //how often does the system check for caster's movement

        // internal temp variables
        private group tempGroup = CreateGroup()
        private rect tempRect = Rect(0.00, 0.00, 0.00, 0.00)
        private integer index
        private integer endIndex
        private unit target
        private real targetDistance
        private real angleT
        private real tempReal
        private location tempLoc = Location(0.00, 0.00)
    endglobals

    public struct Instance
        unit caster
        real beamDistancePerTick
        real beamMaxDistance
        real beamAngle
        real beamWidth
        real beamWidthSquare
        real beamStartX
        real beamStartY
        real beamInitialDamage
        real beamStaticDamageSecondsPerTick
        real damagePerTick
        string lightningCode
        integer lightningCount
        string lingeringEffectModel
        integer effectEveryXTicks
        real lingeringEffectScale
        real lingeringEffectTimescale

        real casterX
        real casterY
        real casterZ

        real beamDistance
        real beamDeltaX
        real beamDeltaY
        real beamEndX
        real beamEndY
        real dissipateDistance
        timer beamMovement
        timer damageTimer
        timer dissipationTimer
        group damageGroup
        integer effectCount
        integer effectTickCounter
        integer deletedEffectCount
        integer deletedEffectTickCounter
        Table lightningData
        Table effectData

        private static method getTerrainZ takes real x, real y returns real
            call MoveLocation(tempLoc, x, y)
            return GetLocationZ(tempLoc)
        endmethod

        private method enumNearbyUnits takes real x1, real y1, real x2, real y2 returns nothing
            // sort coordinates by value
            if x1 > x2 then
                set tempReal = x1
                set x1 = x2
                set x2 = tempReal
            endif
            if y1 > y2 then
                set tempReal = y1
                set y1 = y2
                set y2 = tempReal
            endif

            call SetRect(tempRect, x1 - this.beamWidth, y1 - this.beamWidth, x2 + this.beamWidth, y2 + this.beamWidth)
            call GroupEnumUnitsInRect(tempGroup, tempRect, null)
        endmethod

        private method isTargetInRange takes real targetX, real targetY returns boolean
            //A slightly modified Distance between a line and a point formula 
            //Ax + By + C = 0 => -ax + y + b = 0 from y = ax - b, where a = tan(angle) and b = a(x1) - y1
            //Formula: |Ax + By + C|/Sqrt(A^2 + B^2)=> ((-ax + y + b)^2)/(a^2 + 1)
            set angleT = Tan(this.beamAngle)
            set targetDistance = Pow(- angleT * targetX + targetY + angleT * this.beamStartX - this.beamStartY, 2) / (Pow(angleT, 2) + 1)
            return targetDistance <= this.beamWidthSquare
        endmethod

        private static method StaticBeamDamage takes nothing returns nothing
            local thistype this = GetTimerData(GetExpiredTimer())
            call GroupEnumUnitsInRange(tempGroup, this.beamEndX, this.beamEndY, this.beamWidth, null)
            set index = 0
            set endIndex = BlzGroupGetSize(tempGroup)
            loop
                exitwhen index >= endIndex
                set target = BlzGroupUnitAt(tempGroup, index)

                if target != this.caster then
                    call this.initialUnitCollisionHandler(target)
                endif

                set index = index + 1
            endloop
        endmethod

        private static method PeriodicMovement takes nothing returns nothing
            local thistype this = GetTimerData(GetExpiredTimer())

            call this.createLingeringEffect(this.beamEndX, this.beamEndY)
            set this.beamDistance = this.beamDistance + this.beamDistancePerTick
            call enumNearbyUnits(this.beamEndX, this.beamEndY, this.beamEndX + this.beamDeltaX, this.beamEndY + this.beamDeltaY)
            set this.beamEndX = this.beamEndX + this.beamDeltaX
            set this.beamEndY = this.beamEndY + this.beamDeltaY
            call this.moveBeamVisual(this.beamEndX, this.beamEndY)

            set index = 0
            set endIndex = BlzGroupGetSize(tempGroup)
            loop
                exitwhen index >= endIndex
                set target = BlzGroupUnitAt(tempGroup, index)

                if not IsUnitInGroup(target, this.damageGroup) and target != this.caster and this.isTargetInRange(GetUnitX(target), GetUnitY(target)) then
                    call GroupAddUnit(this.damageGroup, target)
                    call this.initialUnitCollisionHandler(target)
                endif

                set index = index + 1
            endloop

            if this.beamDistance >= this.beamMaxDistance then
                call PauseTimer(this.beamMovement)
                call TimerStart(this.beamMovement, this.beamStaticDamageSecondsPerTick, true, function thistype.StaticBeamDamage)
            endif
        endmethod

        private static method Damage takes nothing returns nothing
            local thistype this = GetTimerData(GetExpiredTimer())
            call enumNearbyUnits(this.beamStartX, this.beamStartY, this.beamEndX, this.beamEndY)
        
            set index = 0
            set endIndex = BlzGroupGetSize(tempGroup)
            loop
                exitwhen index >= endIndex
                set target = BlzGroupUnitAt(tempGroup, index)

                if target != this.caster and this.isTargetInRange(GetUnitX(target), GetUnitY(target)) then
                    call this.tickedUnitCollisionHandler(target)
                endif

                set index = index + 1
            endloop
        endmethod

        private method dissipate takes nothing returns nothing
            call this.destroyLingeringEffect(this.beamStartX, this.beamStartY)
            set this.beamStartX = this.beamStartX + this.beamDeltaX
            set this.beamStartY = this.beamStartY + this.beamDeltaY
            set this.dissipateDistance = this.dissipateDistance + this.beamDistancePerTick

            if this.dissipateDistance >= this.beamDistance then
                call this.destroy()
            endif
        endmethod

        private static method DissipateTick takes nothing returns nothing
            local thistype this = GetTimerData(GetExpiredTimer())
            call this.dissipate()
        endmethod

        private static method StartDissipating takes nothing returns nothing
            local thistype this = GetTimerData(GetExpiredTimer())
            call this.stop()
            call TimerStart(this.dissipationTimer, BEAM_MOVEMENT_TICK, true, function thistype.DissipateTick)
            call this.dissipate()
        endmethod

        public static method create takes unit caster, real initialDamage, real damagePerTick, real secondsPerTick, real beamStaticDamageSecondsPerTick, real duration, real startX, real startY, real angle, real width, real maxDistance, real beamMS, real casterHeightOffset, string lightningCode, integer lightningCount, string lingeringEffectModel, integer effectEveryXTicks, real lingeringEffectScale, real lingeringEffectTimescale returns thistype
            local thistype this = thistype.allocate()
            set this.caster = caster
            set this.beamStartX = startX
            set this.beamStartY = startY
            set this.beamEndX = startX
            set this.beamEndY = startY
            set this.beamWidth = width/2
            set this.beamStaticDamageSecondsPerTick = beamStaticDamageSecondsPerTick
            set this.beamDistancePerTick = beamMS * BEAM_MOVEMENT_TICK
            set this.beamMaxDistance = maxDistance
            set this.beamAngle = angle
            set this.beamInitialDamage = initialDamage
            set this.damagePerTick = damagePerTick
            set this.casterX = GetUnitX(caster)
            set this.casterY = GetUnitY(caster)
            set this.casterZ = BlzGetUnitZ(caster) + casterHeightOffset
            set this.lightningCount = lightningCount
            set this.lightningCode = lightningCode
            set this.lingeringEffectModel = lingeringEffectModel
            set this.effectEveryXTicks = effectEveryXTicks
            set this.lingeringEffectScale = lingeringEffectScale
            set this.lingeringEffectTimescale = lingeringEffectTimescale

            set this.beamWidthSquare = this.beamWidth * this.beamWidth
            set this.beamDeltaX = this.beamDistancePerTick * Cos(this.beamAngle)
            set this.beamDeltaY = this.beamDistancePerTick * Sin(this.beamAngle)
            set this.beamDistance = 0.00
            set this.dissipateDistance = 0.00
            set this.effectCount = 0
            set this.effectTickCounter = 0
            set this.deletedEffectCount = 0
            set this.deletedEffectTickCounter = 0

            set this.damageGroup = CreateGroup()
            set this.beamMovement = NewTimerEx(this)
            call TimerStart(this.beamMovement, BEAM_MOVEMENT_TICK, true, function thistype.PeriodicMovement)

            if this.damagePerTick > 0 then
                set this.damageTimer = NewTimerEx(this)
                call TimerStart(this.damageTimer, secondsPerTick, true, function thistype.Damage)
            endif

            set this.dissipationTimer = NewTimerEx(this)
            call TimerStart(this.dissipationTimer, duration, false, function thistype.StartDissipating)
            
            set this.lightningData = Table.create()
            set this.effectData = Table.create()
            set index = 0
            loop
                exitwhen index >= lightningCount
                set this.lightningData.lightning[index] = AddLightningEx(this.lightningCode, true, this.casterX, this.casterY, this.casterZ, startX, startY, getTerrainZ(startX, startY))
                set index = index + 1
            endloop

            return this
        endmethod

        public method stop takes nothing returns nothing
            call PauseTimer(this.beamMovement)
            call this.destroyBeamVisual()
        endmethod

        public method destroy takes nothing returns nothing
            call PauseTimer(this.beamMovement)
            call ReleaseTimer(this.beamMovement)
            call PauseTimer(this.damageTimer)
            call ReleaseTimer(this.damageTimer)
            call PauseTimer(this.dissipationTimer)
            call ReleaseTimer(this.dissipationTimer)
            call DestroyGroup(this.damageGroup)
            set this.caster = null
            call this.lightningData.flush()
            call this.effectData.flush()
        endmethod

        public method initialUnitCollisionHandler takes unit u returns nothing
            set udg_EyeBeamCausedDamage = true
            call UnitDamageTarget(this.caster, target, this.beamInitialDamage, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            set udg_EyeBeamCausedDamage = false
        endmethod

        public method tickedUnitCollisionHandler takes unit u returns nothing
            set udg_EyeBeamCausedLingeringDamage = true
            call UnitDamageTarget(this.caster, target, this.damagePerTick, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            set udg_EyeBeamCausedLingeringDamage = false
        endmethod

        public method moveBeamVisual takes real x, real y returns nothing
            set index = 0
            loop
                exitwhen index >= this.lightningCount
                call MoveLightningEx(this.lightningData.lightning[index], true, this.casterX, this.casterY, this.casterZ, x, y, getTerrainZ(x, y))
                set index = index + 1
            endloop
        endmethod

        public method destroyBeamVisual takes nothing returns nothing
            set index = 0
            loop
                exitwhen index >= this.lightningCount
                call DestroyLightning(this.lightningData.lightning[index])
                set index = index + 1
            endloop
        endmethod

        public method createLingeringEffect takes real x, real y returns nothing
            local effect ef = null
            set this.effectTickCounter = this.effectTickCounter + 1
            if this.effectEveryXTicks != this.effectTickCounter then
                return
            endif
            set this.effectTickCounter = 0
            set ef = AddSpecialEffect(this.lingeringEffectModel, x, y)
            call BlzSetSpecialEffectScale(ef, this.lingeringEffectScale)
            call BlzSetSpecialEffectTimeScale(ef, this.lingeringEffectTimescale)
            set this.effectData.effect[this.effectCount] = ef
            set this.effectCount = this.effectCount + 1
            set ef = null
        endmethod

        public method destroyLingeringEffect takes real x, real y returns nothing
            local effect ef = null
            set this.deletedEffectTickCounter = this.deletedEffectTickCounter + 1
            if this.effectEveryXTicks != this.deletedEffectTickCounter then
                return
            endif
            set this.deletedEffectTickCounter = 0
            set ef = this.effectData.effect[this.deletedEffectCount]
            call BlzSetSpecialEffectZ(ef, -1000)
            call DestroyEffect(ef)
            set this.deletedEffectCount = this.deletedEffectCount + 1
            set ef = null
        endmethod
    endstruct
endlibrary