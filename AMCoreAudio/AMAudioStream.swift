//
//  AMAudioStream.swift
//  AMCoreAudio
//
//  Created by Ruben Nine on 13/04/16.
//  Copyright © 2016 9Labs. All rights reserved.
//

import Foundation

///// `AMAudioStreamEvent` enum
public enum AMAudioStreamEvent: AMEvent {
    /**
        Called whenever the audio stream `isActive` flag changes state.
     */
    case isActiveDidChange(audioStream: AMAudioStream)

    /**
        Called whenever the audio stream physical format changes.
     */
    case physicalFormatDidChange(audioStream: AMAudioStream)
}

/**
    `AMAudioStream`
 
    This class represents an audio stream belonging to an audio object.
 */
final public class AMAudioStream: AMAudioObject {

    // MARK: - Public Properties

    /**
        This audio stream's identifier.

        - Returns: An `AudioObjectID`.
     */
    public var id: AudioObjectID {
        get {
            return objectID
        }
    }

    /**
        Returns whether this audio stream is enabled and doing I/O.
     
        - Returns: `true` when enabled, `false` otherwise.
     */
    public lazy var active: Bool = {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyIsActive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )

        if !AudioObjectHasProperty(self.id, &address) {
            return false
        }

        var active: UInt32 = 0
        let status = self.getPropertyData(address, andValue: &active)

        if noErr != status {
            return false
        }

        return active == 1
    }()

    /**
        Specifies the first element in the owning device that corresponds to the element one of this stream.

        - Returns: *(optional)* A `UInt32`.
     */
    public lazy var startingChannel: UInt32? = {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyStartingChannel,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )

        if !AudioObjectHasProperty(self.id, &address) {
            return nil
        }

        var startingChannel: UInt32 = 0
        let status = self.getPropertyData(address, andValue: &startingChannel)

        if noErr != status {
            return nil
        }

        return startingChannel
    }()

    /**
        Describes the general kind of functionality attached to this stream.
     
        - Return: A `TerminalType`.
    */
    public lazy var terminalType: TerminalType = {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyTerminalType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )

        if !AudioObjectHasProperty(self.id, &address) {
            return .Unknown
        }

        var terminalType: UInt32 = 0
        let status = self.getPropertyData(address, andValue: &terminalType)

        if noErr != status {
            return .Unknown
        }

        switch terminalType {
        case kAudioStreamTerminalTypeLine:
            return .Line
        case kAudioStreamTerminalTypeDigitalAudioInterface:
            return .DigitalAudioInterface
        case kAudioStreamTerminalTypeSpeaker:
            return .Speaker
        case kAudioStreamTerminalTypeHeadphones:
            return .Headphones
        case kAudioStreamTerminalTypeLFESpeaker:
            return .LFESpeaker
        case kAudioStreamTerminalTypeReceiverSpeaker:
            return .ReceiverSpeaker
        case kAudioStreamTerminalTypeMicrophone:
            return .Microphone
        case kAudioStreamTerminalTypeHeadsetMicrophone:
            return .HeadsetMicrophone
        case kAudioStreamTerminalTypeReceiverMicrophone:
            return .ReceiverMicrophone
        case kAudioStreamTerminalTypeTTY:
            return .TTY
        case kAudioStreamTerminalTypeHDMI:
            return .HDMI
        case kAudioStreamTerminalTypeDisplayPort:
            return .DisplayPort
        case kAudioStreamTerminalTypeUnknown:
            fallthrough
        default:
            return .Unknown
        }
    }()

    /**
        The audio stream's direction.

        For output streams, and to continue using the same `Direction` concept used by `AMAudioDevice`,
        this will be `Direction.Playback`, likewise, for input streams, `Direction.Recording` will be returned.

        - Returns: *(optional)* A `Direction`.
     */
    public lazy var direction: Direction? = {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyDirection,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )

        if !AudioObjectHasProperty(self.id, &address) {
            return nil
        }

        var direction: UInt32 = 0
        let status = self.getPropertyData(address, andValue: &direction)

        if noErr != status {
            return nil
        }

        switch direction {
        case 0:
            return .Playback
        case 1:
            return .Recording
        default:
            return nil
        }
    }()

    /**
        An `AudioStreamBasicDescription` that describes the current data format for this audio stream.
     
        - SeeAlso: `virtualFormat`

        - Returns: *(optional)* An `AudioStreamBasicDescription`.
     */
    public var physicalFormat: AudioStreamBasicDescription? {
        get {
            var asbd = AudioStreamBasicDescription()

            if let status = getStreamPropertyData(kAudioStreamPropertyPhysicalFormat, andValue: &asbd) {
                if noErr == status {
                    return asbd
                }
            }

            return nil
        }

        set {
            var asbd = newValue

            if let status = setStreamPropertyData(kAudioStreamPropertyPhysicalFormat, andValue: &asbd) {
                if noErr != status {
                    print("Error setting physicalFormat to \(newValue)")
                }
            }
        }
    }

    /**
        An `AudioStreamBasicDescription` that describes the current virtual data format for this audio stream.

        - SeeAlso: `physicalFormat`

        - Returns: *(optional)* An `AudioStreamBasicDescription`.
     */
    public var virtualFormat: AudioStreamBasicDescription? {
        get {
            var asbd = AudioStreamBasicDescription()

            if let status = getStreamPropertyData(kAudioStreamPropertyVirtualFormat, andValue: &asbd) {
                if noErr == status {
                    return asbd
                }
            }

            return nil
        }

        set {
            var asbd = newValue

            if let status = setStreamPropertyData(kAudioStreamPropertyVirtualFormat, andValue: &asbd) {
                if noErr != status {
                    print("Error setting virtualFormat to \(newValue)")
                }
            }
        }
    }

    /**
        All the available physical formats for this audio stream.
     
        - SeeAlso: `availableVirtualFormats`

        - Returns: *(optional)* An array of `AudioStreamRangedDescription` structs.
     */
    public lazy var availablePhysicalFormats: [AudioStreamRangedDescription]? = {
        guard let direction = self.direction else {
            return nil
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyAvailablePhysicalFormats,
            mScope: self.directionToScope(direction),
            mElement: kAudioObjectPropertyElementMaster
        )

        if !AudioObjectHasProperty(self.id, &address) {
            return nil
        }

        var asrd = [AudioStreamRangedDescription]()
        let status = self.getPropertyDataArray(address, value: &asrd, andDefaultValue: AudioStreamRangedDescription())

        if noErr != status {
            return nil
        }

        return asrd
    }()

    /**
        All the available virtual formats for this audio stream.
     
        - SeeAlso: `availablePhysicalFormats`

        - Returns: *(optional)* An array of `AudioStreamRangedDescription` structs.
     */
    public lazy var availableVirtualFormats: [AudioStreamRangedDescription]? = {
        guard let direction = self.direction else {
            return nil
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyAvailableVirtualFormats,
            mScope: self.directionToScope(direction),
            mElement: kAudioObjectPropertyElementMaster
        )

        if !AudioObjectHasProperty(self.id, &address) {
            return nil
        }

        var asrd = [AudioStreamRangedDescription]()
        let status = self.getPropertyDataArray(address, value: &asrd, andDefaultValue: AudioStreamRangedDescription())

        if noErr != status {
            return nil
        }
        
        return asrd
    }()

    // MARK: - Private Properties

    private var isRegisteredForNotifications = false

    private lazy var notificationsQueue: DispatchQueue = {
        return DispatchQueue(label: "io.9labs.AMCoreAudio.notifications", attributes: .concurrent)
    }()

    private lazy var propertyListenerBlock: AudioObjectPropertyListenerBlock = { (inNumberAddresses, inAddresses) -> Void in
        let address = inAddresses.pointee
        let direction = self.scopeToDirection(address.mScope)
        let notificationCenter = AMNotificationCenter.defaultCenter

        switch address.mSelector {
        case kAudioStreamPropertyIsActive:
            notificationCenter.publish(AMAudioStreamEvent.isActiveDidChange(audioStream: self))
        case kAudioStreamPropertyPhysicalFormat:
            notificationCenter.publish(AMAudioStreamEvent.physicalFormatDidChange(audioStream: self))
        default:
            break
        }
    }

    // MARK: - Public Functions

    public static func lookupByID(_ id: AudioObjectID) -> AMAudioStream? {
        var instance = AMAudioObjectPool.instancePool.object(forKey: NSNumber(value: UInt(id))) as? AMAudioStream

        if instance == nil {
            instance = AMAudioStream(id: id)
        }

        return instance
    }

    /**
        Initializes an `AMAudioStream` by providing a valid `AudioObjectID` referencing an existing audio stream.
     */
    private init(id: AudioObjectID) {
        super.init(objectID: id)
        registerForNotifications()
        AMAudioObjectPool.instancePool.setObject(self, forKey: NSNumber(value: UInt(objectID)))
    }

    deinit {
        unregisterForNotifications()
        AMAudioObjectPool.instancePool.removeObject(forKey: NSNumber(value: UInt(objectID)))
    }

    /**
        All the available physical formats for this audio stream matching the current physical format's sample rate.
     
        - Note: By default, both mixable and non-mixable streams are returned, however,  non-mixable
        streams can be filtered out by setting `includeNonMixable` to `false`.

        - Parameters:
            - includeNonMixable: Whether to include non-mixable streams in the returned array. Defaults to `true`.

        - SeeAlso: `availableVirtualFormatsMatchingCurrentNominalSampleRate(_:)`

        - Returns: *(optional)* An array of `AudioStreamBasicDescription` structs.
     */
    public final func availablePhysicalFormatsMatchingCurrentNominalSampleRate(_ includeNonMixable: Bool = true) -> [AudioStreamBasicDescription]? {
        guard let physicalFormats = availablePhysicalFormats,
              let physicalFormat = physicalFormat else {
            return nil
        }

        var filteredFormats = physicalFormats.filter { (format) -> Bool in
            format.mSampleRateRange.mMinimum >= physicalFormat.mSampleRate &&
            format.mSampleRateRange.mMaximum <= physicalFormat.mSampleRate
        }.map({ (asrd) -> AudioStreamBasicDescription in
            asrd.mFormat
        })

        if !includeNonMixable {
            filteredFormats = filteredFormats.filter({ (asbd) -> Bool in
                asbd.mFormatFlags & kAudioFormatFlagIsNonMixable == 0
            })
        }

        return filteredFormats
    }

    /**
        The audio stream's name as reported by the system.

        - Returns: *(optional)* An audio stream's name.
     */
    override public var name: String? {
        return super.name
    }

    /**
        All the available virtual formats for this audio stream matching the current virtual format's sample rate.

        - Note: By default, both mixable and non-mixable streams are returned, however,  non-mixable 
        streams can be filtered out by setting `includeNonMixable` to `false`.

        - Parameters:
            - includeNonMixable: Whether to include non-mixable streams in the returned array. Defaults to `true`.
     
        - SeeAlso: `availablePhysicalFormatsMatchingCurrentNominalSampleRate(_:)`

        - Returns: *(optional)* An array of `AudioStreamBasicDescription` structs.
     */
    public final func availableVirtualFormatsMatchingCurrentNominalSampleRate(_ includeNonMixable: Bool = true) -> [AudioStreamBasicDescription]? {
        guard let virtualFormats = availableVirtualFormats,
            let virtualFormat = virtualFormat else {
                return nil
        }

        var filteredFormats = virtualFormats.filter { (format) -> Bool in
            format.mSampleRateRange.mMinimum >= virtualFormat.mSampleRate &&
                format.mSampleRateRange.mMaximum <= virtualFormat.mSampleRate
            }.map({ (asrd) -> AudioStreamBasicDescription in
                asrd.mFormat
            })

        if !includeNonMixable {
            filteredFormats = filteredFormats.filter({ (asbd) -> Bool in
                asbd.mFormatFlags & kAudioFormatFlagIsNonMixable == 0
            })
        }

        return filteredFormats
    }

    // MARK: - Private Functions

    /**
        This is an specialized version of `getPropertyData` that only requires passing an `AudioObjectPropertySelector`
        instead of an `AudioObjectPropertyAddress`. The scope is computed from the stream's `Direction`, and the element 
        is assumed to be `kAudioObjectPropertyElementMaster`.

        Additionally, the property address is validated before calling `getPropertyData`.

        - Parameter selector: The `AudioObjectPropertySelector` that points to the property we want to get.
        - Parameter value: The value that will be returned.
     
        - Returns: An `OSStatus` with `noErr` on success, or an error code other than `noErr` when it fails.
     */
    private func getStreamPropertyData<T>(_ selector: AudioObjectPropertySelector, andValue value: inout T) -> OSStatus? {
        guard let direction = direction else {
            return nil
        }

        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: directionToScope(direction),
            mElement: kAudioObjectPropertyElementMaster
        )

        if !AudioObjectHasProperty(id, &address) {
            return nil
        }

        return getPropertyData(address, andValue: &value)
    }

    /**
        This is an specialized version of `setPropertyData` that only requires passing an `AudioObjectPropertySelector`
        instead of an `AudioObjectPropertyAddress`. The scope is computed from the stream's `Direction`, and the element
        is assumed to be `kAudioObjectPropertyElementMaster`.

        Additionally, the property address is validated before calling `setPropertyData`.

        - Parameter selector: The `AudioObjectPropertySelector` that points to the property we want to set.
        - Parameter value: The new value we want to set.
     
        - Returns: An `OSStatus` with `noErr` on success, or an error code other than `noErr` when it fails.
     */
    private func setStreamPropertyData<T>(_ selector: AudioObjectPropertySelector, andValue value: inout T) -> OSStatus? {
        guard let direction = direction else {
            return nil
        }

        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: directionToScope(direction),
            mElement: kAudioObjectPropertyElementMaster
        )

        if !AudioObjectHasProperty(id, &address) {
            return nil
        }

        return setPropertyData(address, andValue: &value)
    }

    // MARK: - Notification Book-keeping

    private func registerForNotifications() {
        if isRegisteredForNotifications {
            unregisterForNotifications()
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertySelectorWildcard,
            mScope: kAudioObjectPropertyScopeWildcard,
            mElement: kAudioObjectPropertyElementWildcard
        )

        let err = AudioObjectAddPropertyListenerBlock(id, &address, notificationsQueue, propertyListenerBlock)

        if noErr != err {
            print("Error on AudioObjectAddPropertyListenerBlock: \(err)")
        }

        isRegisteredForNotifications = noErr == err
    }

    private func unregisterForNotifications() {
        if isRegisteredForNotifications {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertySelectorWildcard,
                mScope: kAudioObjectPropertyScopeWildcard,
                mElement: kAudioObjectPropertyElementWildcard
            )

            let err = AudioObjectRemovePropertyListenerBlock(id, &address, notificationsQueue, propertyListenerBlock)

            if noErr != err {
                print("Error on AudioObjectRemovePropertyListenerBlock: \(err)")
            }

            isRegisteredForNotifications = noErr != err
        } else {
            isRegisteredForNotifications = false
        }
    }
}

// MARK: - Deprecated

extension AMAudioStream {
    @available(*, deprecated, message: "Marked for removal in 3.2. Use name instead") public func streamName() -> String? {
        return name
    }

    @available(*, deprecated, message: "Marked for removal in 3.2. Use id instead") public var streamID: AudioObjectID {
        return id
    }
}
