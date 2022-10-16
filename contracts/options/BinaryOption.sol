// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
//import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol";


abstract contract BinaryOption {
    struct option {
        address owner;
        uint256 betLossValue;
        uint256 betWinValue;   
    }    

    address tradeTokenAddress;
    address priceAddress;
    uint256 expiration;

    bool created;
    bool prizesCalculated;            

    mapping(address => uint256) tradersPrizes;

    constructor(address _tradeTokenAddress, address _priceAddress, uint256 _expiration) {
        tradeTokenAddress = _tradeTokenAddress;
        priceAddress = _priceAddress;
        expiration = _expiration;
        prizesCalculated = false;
        created = false;
    }

    modifier isValidOpposits(option[][] memory options) {
        for (uint256 i=0; i<options.length; i++)
            require(options[i].length>0, 
                "There should be at least one complementary option for each opposite option");

        uint256 totalLoss = 0;
        for (uint256 i=0; i<options.length; i++)
                totalLoss += getTotalLossBet(options[i]);

        for (uint256 i=0; i<options.length; i++)
            {
                require(getTotalWinBet(options[i])  == totalLoss - getTotalLossBet(options[i]),
                        "Opposite bet values are not equivalent");                              
            }
        _;
    }

    function getTotalWinBet(option[] memory options) private pure returns(uint256 totalBet){
        for (uint256 i=0; i<options.length; i++)
            totalBet += options[i].betWinValue;
    }

    function getTotalLossBet(option[] memory options) private pure returns(uint256 totalBet){
        for (uint256 i=0; i<options.length; i++)
            totalBet += options[i].betLossValue;
    }

    modifier claculatePrizesModifier {        
        require(created, "Has not been created yet");
        require(!prizesCalculated, "Prize has already been calculated");
        _;
        prizesCalculated = true;
    }

    function claculatePrizes() virtual public;

    modifier createModifier {
        require(block.timestamp < expiration, "Is expired");
        require(!created, "Has already been created");
        _;
        created = true;
    }

    function create() virtual public;

    function lockBettedValues(option[] memory options) internal {
        for (uint256 i=0; i<options.length; i++)
            IERC20(tradeTokenAddress).transferFrom(options[i].owner, 
                                                    address(this), 
                                                    options[i].betLossValue);
    }

    function setPrizes(option[] storage options) internal {
        for (uint256 i=0; i<options.length; i++)
            tradersPrizes[options[i].owner] = options[i].betWinValue + options[i].betLossValue;
    }

    function setRefounds(option[] storage options) internal {
        for (uint256 i=0; i<options.length; i++)
            tradersPrizes[options[i].owner] = options[i].betWinValue + options[i].betLossValue;
    }

    function getPrizeOrRefound() public {
        require(prizesCalculated, "Call claculatePrizes first");
        require(tradersPrizes[msg.sender] > 0, "No prize available");
        
        IERC20(tradeTokenAddress).transfer(msg.sender, tradersPrizes[msg.sender]);

        tradersPrizes[msg.sender] = 0;
    }

    function getLatestPrice() internal view returns (int256) {
        (
            /*uint80 roundID*/,            
            int256 price,
            /*uint startedAt*/,            
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = 
            AggregatorV3Interface(priceAddress).latestRoundData();
        return price;
    }

    function getAndValidateLatestPrice() internal view returns (int256) {
        (
            /*uint80 roundID*/,            
            int256 price,
            /*uint startedAt*/,            
            uint256 updatedAt,
            /*uint80 answeredInRound*/
        ) = 
            AggregatorV3Interface(priceAddress).latestRoundData();
        require(expiration <= updatedAt, "Price data is not updated yet");
        return price;
    }

    function optionsToString(option[] memory options) internal pure returns(string memory retorno) {
        for (uint256 i=0; i<options.length; i++)
            retorno =string.concat(retorno,
                          "\tOwner: ",toAsciiString(options[i].owner),
                          "\n\tbetLossValue: ",Strings.toString(options[i].betLossValue),
                          "\n\tbetWinValue: ",Strings.toString(options[i].betWinValue),
                          "\n");
    }

    function toAsciiString(address x) internal pure returns (string memory) {
    bytes memory s = new bytes(40);
    
    for (uint i = 0; i < 20; i++) {
        bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
        bytes1 hi = bytes1(uint8(b) / 16);
        bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
        s[2*i] = char(hi);
        s[2*i+1] = char(lo);            
    }
    
    return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function viewExpiration() public view returns (uint256) {
        return expiration;
    }

    function viewPriceAddress() public view returns (address) {
        return priceAddress;
    }

    function viewTradeTokenAddress() public view returns (address) {
        return tradeTokenAddress;
    }
}
