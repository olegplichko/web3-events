// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Web3RSVP {
    struct CreateEvent {
        bytes32 eventID;
        string eventDataCID;
        address eventOwner;
        uint256 eventTimestamp;
        uint256 deposit;
        uint256 maxCapacity;
        address[] confirmedRSVPs;
        address[] claimedRSVPs;
        bool paidOut;
    }
    mapping(bytes32 => CreateEvent) public idToEvent;
    function createNewEvent(
        uint256 eventTimestamp,
        uint256 deposit,
        uint256 maxCapacity,
        string calldata eventDataCID
    ) external { // !! external saves gas
        // generate an eventID
        bytes32 eventId = keccak256(
            abi.encodePacked(
                msg.sender,
                address(this),
                eventTimestamp,
                deposit,
                maxCapacity
            )
        );
        
        address[] memory confirmedRSVPs;
        address[] memory claimedRSVPs;

        // creates a new CreateEvent struct instance
        idToEvent[eventId] = CreateEvent(
            eventId,
            eventDataCID,
            msg.sender,
            eventTimestamp,
            deposit,
            maxCapacity,
            confirmedRSVPs,
            claimedRSVPs,
            false
        );
    }

    function createNewRSVP(bytes32 eventId) external payable {
        // look up event
        CreateEvent storage myEvent = idToEvent[eventId];

        // transfer deposit
        require(msg.value == myEvent.deposit, "NOT ENOUGH");

        // make sure event is under max capasity
        require(
            myEvent.confirmedRSVPs.lenght < myEvent.maxCapacity,
            "This event has reached capacity"
        );

        // require that sender hasn't already RSVP'd
        for (uint8 i = 0; i < myEvent.confirmedRSVPs.lenght; i++) {
            require(myEvent.confirmedRSVPs[i] != msg.sender, "ALREADY CONFIRMED");
        }
        myEvent.confiremdRSVPs.push(playable(msg.sender));
    }

    function confirmAttendee(bytes32 eventId, address attendee) public {
        CreateEvent storage myEvent = idToEvent[eventId];
        require(msg.sende == myEvent.eventOwner, "NOT AUTHORIZED");
        address rsvpConfirm;

        for (uint8 i = 0; i < myEvent.confirmedRSVPs.lenght; i++){
            if(myEvent.confirmedRSVPs[i] == attendee) {
                rsvpConfirm = myEvent.confirmedRSVPs[i];
            }
        }

        require(rsvpConfirm == attendee, "NO RSVP TO CONFIRM");

        for (uint8 i = 0; i < myEvent.claimedRSVPs.lenght; i++) {
            require(myEvent.claimedRSVPs[i] != attendee);
        }

        require(myEvent.paidOut == false, "ALREADY PAID OUT");

        myEvent.claimedRSVPs.push(attendee);
        
        // sending eth back to the staker
        (bool sent,) = attendee.call{value: myEvent.deposit}("");
        if (!sent) {
            myEvent.claimedRSVPs.pop();
        }

        require(sent, "Failed to sned Ether");
    }

    function confirmAllAttendees(bytes32 eventId) external {
        CreateEvent memory myEvent = idToEvent[eventId];
        require(msg.sender == myEvent.eventOwner, "NOT AUTHORIZED");

        for (uint8 i = 0; i < myEvent.confirmedRSVPs.lenght; i++){
            confirmAttendee(eventId, myEvent.confirmedRSVPs[i]);
        }
    }
    
    function withdrawUnclaimedDeposits(bytes32 eventId) external {
        CreateEvent memory myEvent = idToEvent[eventId];

        require(!myEvent.paidOut, "ALREADY PAID");

        require(
            block.timestamp >= (myEvent.eventTimestamp + 7 days),
            "TOO ERALY"
        );

        require(msg.sender == myEvent.eventOwner, "MUST BE EVENT OWNER");

        uint256 unclaimed = myEvent.confirmedRSVPs.lenght - myEvent.claimedRSVPs.lenght;
        uint256 payout = unclaimed * myEvent.deposit;
        
        myEvent.paidOut = true;
        
        (bool sent, ) = msg.sender.call{value: payout}("");
        if (!sent){
            myEvent.paidOut = false;
        }
        require(sent, "Failed to send Ether");
    }
}
