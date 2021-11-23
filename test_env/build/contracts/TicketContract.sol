pragma solidity 0.6.6;

contract TicketInsurance{

    // Environmental variables
    address public contractOwner;

    // Mappings

    // Constructors
    constructor() public {
        contractOwner = msg.sender;
    }

    // Structs

    struct Ticket {
        address owner;
        uint ticket_id;
        uint train_number;
        uint price;
        uint datetime_departure;
        uint datetime_arrival_predicted;
        string station_departure;
        string station_arrival;
    }

    mapping(address => mapping(uint => Ticket)) tickets_database;

    // Functions

    function UploadTickets(uint _trainNumber, uint _price, uint _datetimeDeparture, 
                           uint _datetimeArrivalPredicted, string memory _stationDeparture, 
                           string memory _stationArrival) public {
        require(msg.sender == contractOwner, "You're not Italo. You cannot upload any ticket.");
        // uint _totalNumberTickets
        //for (uint i=0; i<_totalNumberTickets; i++)

        uint _id = 0; 
        tickets_database[msg.sender][_id] = Ticket(msg.sender, _id, _trainNumber, _price, _datetimeDeparture, _datetimeArrivalPredicted,
        _stationDeparture,  _stationArrival);
    }

    function SeeYourTicket(uint _ticketId) public view returns (string memory) {
        address owner = msg.sender;
        uint ticket_id = _ticketId;
        string memory myticket_station = tickets_database[owner][ticket_id].station_departure;
        
        return myticket_station;
    }

}

// Ticket Contract, in general:
// 1. Define functionalities
// 2. Contract communicating with Oracles

// Data:
// 1. Ticket information: ticket_id, number of the train, datetime of departure, datetime of arrival (planned), datetime of arrival (actual),
//                        departure station, arrival station, price, msg.sender, our wallets (reimbursment wallet - profit wallet),
//                        hash(id and train id).

// ORACLE DATA

// Functions:
// 1. UploadTickets_ByItalo(number of train, datetime of departure, datetime of arrival(planned), departure station, arrival station, price, NUMBER OF TICKETS)
// 2. BuyTicket(msg.sender, number of the train, datetime of departure, departure station, arrival station, NUMBER_TICKET)
// 3. CheckYourTicket(msg.sender) it will return your ticket information
// 4. GetOracleData() must raise an event calling the CheckRefund function and must feed the CheckRefund with train number and true arrival time
// 5. CheckRefund(train number, true arrival time) and will call the Refund for all the ticket owners that respect the criterion
// 6. Refund(ticket owner, ticket id) will send back the money to the owner

// REQUIREMENTS and returns:
// 1. Sanity check for datetime (check for consistency)
// 2. Error message for any other inconsistency in stations, prices

// More ideas:
// 1. Checking whether the person was actually on the train
// 2. Further developments for seats class (economy, business) and refund proportional
// 3. Add other stop stations


// ACTUAL CODE: