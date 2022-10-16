// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


contract MockAggregatorV3 {

    uint80 roundId;            
    int256 price;
    uint startedAt;            
    uint256 updatedAt;
    uint80 answeredInRound;

    constructor() {}

    function setData(
        uint80 _roundId,            
        int256 _price,
        uint _startedAt,            
        uint256 _updatedAt,
        uint80 _answeredInRound
    )  public {
        roundId = _roundId;            
        price = _price;
        startedAt = _startedAt;            
        updatedAt = _updatedAt;
        answeredInRound = _answeredInRound;
    }

    function latestRoundData()
    external
    view
    returns (
      uint80,
      int256,
      uint256,
      uint256,
      uint80
    ) {
        return(roundId,
               price,
               startedAt,
               updatedAt,
               answeredInRound
            );
    }

}