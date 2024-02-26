// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract BoxingBonanza is VRFV2WrapperConsumerBase {
    address owner;
    event PlaceBetRequest(uint256 requestId);
    event PlaceBetResult(address player, uint256 requestId, bool didWin);
    enum BetSelection {RED, DRAW, BLUE}
    struct PlaceBetStatus {
        uint256 fees;
        uint256 randomWord;
        address player;
        bool didWin;
        bool fulfilled;
        BetSelection choice;
        uint256 betAmount;
        uint256 winningResult;
    }
    mapping (uint256 => PlaceBetStatus) public statuses;
    struct WinStats {
        uint256 redWins;
        uint256 drawWins;
        uint256 blueWins;
    }
    WinStats public winStats;


    uint32 constant callbackGasLimit = 3000000;
    uint32 constant numWords = 1;
    uint16 constant requestConfirmations = 3;


    address constant linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant vrfWrapper = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;


    constructor() payable VRFV2WrapperConsumerBase(linkAddress, vrfWrapper) {
        owner = msg.sender;
    }


    function placeBet(BetSelection choice) external payable returns (uint256) {
        uint256 requestId = requestRandomness(callbackGasLimit, requestConfirmations, numWords);
        statuses[requestId] = PlaceBetStatus({
            fees: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomWord: 0,
            player: msg.sender,
            didWin: false,
            fulfilled: false,
            choice: choice,
            betAmount: msg.value,
            winningResult: 0
        });


        emit PlaceBetRequest(requestId);
        return requestId;
    }


    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(statuses[requestId].fees > 0, "Request not found");
        statuses[requestId].fulfilled = true;
        statuses[requestId].randomWord = randomWords[0];
        uint256 result = randomWords[0] % 3;
        statuses[requestId].winningResult = result;


        if (statuses[requestId].choice == BetSelection(result)) {
            statuses[requestId].didWin = true;
            payable(statuses[requestId].player).transfer(statuses[requestId].betAmount * 3);
        }


        if (result == 0) winStats.redWins++;
        else if (result == 1) winStats.drawWins++;
        else if (result == 2) winStats.blueWins++;


        emit PlaceBetResult(statuses[requestId].player, requestId, statuses[requestId].didWin);
    }


    function getStatus(uint256 requestId) public view returns (PlaceBetStatus memory) {
        return statuses[requestId];
    }


    function getWinStats() public view returns (WinStats memory) {
        return winStats;
    }


    function getLinkBalance() public view returns (uint256) {
        return IERC20(linkAddress).balanceOf(address(this));
    }


    function getEthBalance() public view returns (uint256) {
        require(msg.sender == owner, "Only the contract owner can withdraw. The player winnings are automatically sent to the winners");
        return address(this).balance;
    }


    function withdrawLink(uint256 amount) external {
        require(msg.sender == owner, "Only the contract owner can withdraw. The player winnings are automatically sent to the winners");
        IERC20(linkAddress).transfer(msg.sender, amount);
    }


    function withdrawEth(uint256 amount) external {
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {}
}

//0xbF3F5238a76aa3570e1D30d1F8Bc142A31E33f38
