pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Betting is Ownable {

    // Initial Variables
    uint public feePercentage = 2;
    uint public feesCollected = 0;
    address payable withdrawalAddress = payable(0xC864CAE94430fC3b7daA2b1CBB62A5127c8ce66C);

    // Events
    event BetStarted(bytes32 _gameID);
    event BetCreated(bytes32 _gameID);
    event bettingFeeTaken(uint _amountTaken);


    // Defining a Bet Item (Struct)
    struct Bet {
        // 2 bettors, with a payable address and an amount bet each
        address payable bettor1;
        address payable bettor2;
        uint betAmount1;
        uint betAmount2;
        // Game ID
        bytes32 gameID;
    }

    // This can be used by the frontend to link one player to another in a bet
    struct BetInitializer {
        address payable iniatialBettor;
        bytes32 gameID;
        uint betAmount;
    }

    // Mappings (structs can be saved as the value, but not the key FYI)
    
    // Maps each gameID to a Bet struct and stores in a dictionary of bets
    mapping (bytes32 => Bet ) bets; 

    // Maps the initial gameID to the betInitializer
    mapping (bytes32 => BetInitializer) initialBets;


    //--------------------------------------------------------------
    // Public Functions

    // The first bettor will call this
    function firstBet(address payable _opponentAddress) external payable {
        // Initialize the bet, the frontend can grab the opponent address and send it with the call
        initializeBet(msg.sender, payable(_opponentAddress), msg.value);
    }

    // The second bettor will call this (The frontend can concatenate the two addresses and send it with the call)
    function secondBet(bytes32 _gameID) external payable{
        followUpBet(payable(msg.sender), _gameID, msg.value);
    }
   


    
    //---------------------------------------------------------------
    // Private Functions (will be called by functions above)

    // This will be the first portion that is called when the bet is initialized
    function initializeBet(address _initialSender, address payable _opponentAddress, uint _betAmount) private {
        // Create a string for the gameID (Just a string of the two concatenated addresses)
        bytes32 _gameIDString = keccak256(abi.encodePacked(_initialSender, _opponentAddress));

        // Create a betInitializer
        BetInitializer memory initial_bet = BetInitializer(payable(_initialSender), _gameIDString, _betAmount);

        // Store it in the initial Bets mapping
        initialBets[_gameIDString] = initial_bet;

        emit BetStarted(_gameIDString);
    }

    // This will be followed up by the second bettor (can look up the gameID string by concatenating the two addresses)
    function followUpBet(address payable _followUpSender, bytes32 _gameID, uint _betAmount) private {
        // Look up the initial bet given the gameID
        BetInitializer memory initial_bet = initialBets[_gameID];

        // Make sure that the first bet from mapping = _betAmount
        require(initial_bet.betAmount == _betAmount);

        // Take the Fee
        uint totalBetAmount = _betAmount * 2;
        // Calculating differently as we need to keep this as an integer
        uint FeeTaken = (totalBetAmount * feePercentage) / 100;
        //uint FeeTaken = totalBetAmount * (feePercentage / 100);
        uint finalBetAmount = ((totalBetAmount - FeeTaken) / 2);
        feesCollected = feesCollected + FeeTaken;
        emit bettingFeeTaken(FeeTaken);

        // Now that everything has been followed up on, we can create the Bet object
        Bet memory new_bet = Bet(initial_bet.iniatialBettor, _followUpSender, finalBetAmount, finalBetAmount, _gameID);
        bets[_gameID] = new_bet;

        emit BetCreated(_gameID);
    }


    // Internal Functions
    function addressToString(address _address) internal pure returns(string memory) {
        bytes32 _bytes = bytes32(uint256(uint160(_address)));
        bytes memory HEX = "0123456789abcdef";
        bytes memory _string = new bytes(42);
        _string[0] = '0';
        _string[1] = 'x';
        for(uint i = 0; i < 20; i++) {
            _string[2+i*2] = HEX[uint8(_bytes[i + 12] >> 4)];
            _string[3+i*2] = HEX[uint8(_bytes[i + 12] & 0x0f)];}
        return string(_string);
    }
 

   

    //---------------------------------------------------------------
    //View Functions

    // Frontend can call this to get the most recent gameID
    function getGameInfo(bytes32 _gameID) external view returns(uint){
        Bet memory my_bet = bets[_gameID];

        return(my_bet.betAmount1*2);
    }

    //---------------------------------------------------------------
    // Owner Only Functions


    function updateFee (uint _feePercentage) external onlyOwner {
        feePercentage = _feePercentage;
    }

    function withdrawFees() external onlyOwner {
        withdrawalAddress.transfer(feesCollected);
        feesCollected = 0;
    }

    function updateWithdrawalAddress(address _newWithdrawalAddress) external onlyOwner{
        withdrawalAddress = payable(_newWithdrawalAddress);
    }

    // At the end of a game, the frontend run by the owner will perform the logic for payouts
    function winnerDecided(bytes32 _gameID, address _winnerAddress) external onlyOwner {
        // Look up the bet
        Bet memory finalBet = bets[_gameID];

        // Figure out the terms for transfer (amount + who the winner is)
        uint amountToTransfer = finalBet.betAmount1 + finalBet.betAmount2;
        address payable winner; 

        // Identify the winning address
        if (finalBet.bettor1 == _winnerAddress) {
            winner = payable(finalBet.bettor1);
        } else {
            winner = payable(finalBet.bettor2);
        }

        // Transfer money to the winner
        winner.transfer(amountToTransfer);
    }
}
