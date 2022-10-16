import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Token contract", function () {
  const initialBalance = 1000;

  async function deployTokenAndAggregatorAndCreateSomeAddressesWithTokensFixture() {
    const Token = await ethers.getContractFactory("TokenA");
    const [owner, addrA1, addrA2, addrB1, addrB2, addrC1] = await ethers.getSigners();

    const token = await Token.deploy();
    await token.deployed();

    await token.transfer(addrA1.address, initialBalance);
    await token.transfer(addrA2.address, initialBalance);
    await token.transfer(addrB1.address, initialBalance);
    await token.transfer(addrB2.address, initialBalance);
    await token.transfer(addrC1.address, initialBalance);

    const Aggregator = await ethers.getContractFactory("MockAggregatorV3");

    const aggregator = await Aggregator.deploy();
    await aggregator.deployed();

    return { Token, token, owner, addrA1, addrA2, addrB1, addrB2, addrC1, Aggregator, aggregator };
  }

  describe("Simple Binary Option Test", function () {
    
    it("Test Price Limit Binary Option", async function () {
      const { token, aggregator, addrA1, addrB1 } = await loadFixture(deployTokenAndAggregatorAndCreateSomeAddressesWithTokensFixture);
      
      const PriceLimit = await ethers.getContractFactory("PriceLimit");

      const betExpirationTime = (await ethers.provider.getBlock("latest")).timestamp + 60*10;
      

      const betA1 = {
        owner: addrA1.address,
        betLossValue: 100,
        betWinValue: 200
      }

      const betB1 = {
        owner: addrB1.address,
        betLossValue: 200,
        betWinValue: 100
      }

      const betPrice = 1665714038;

      const pricelimit = await PriceLimit.deploy(token.address, 
                                                 aggregator.address,
                                                 betExpirationTime,
                                                 [[betA1],[betB1]],
                                                 betPrice,
                                                 0);
      await pricelimit.deployed();

      await expect(pricelimit.create()).to.be.revertedWith("ERC20: insufficient allowance");

      await token.connect(addrA1).approve(pricelimit.address, betA1.betLossValue);
      await token.connect(addrB1).approve(pricelimit.address, betB1.betLossValue);

      await pricelimit.create();

      await expect(pricelimit.create()).to.be.revertedWith("Has already been created");
      await expect(pricelimit.claculatePrizes()).to.be.revertedWith("It isn't expired");

      await ethers.provider.send("evm_increaseTime", [3600]);

      await aggregator.setData(1, 
                              betPrice+1, 
                              betExpirationTime+1,
                              betExpirationTime+1,
                              0)

      await pricelimit.claculatePrizes();

      await pricelimit.connect(addrA1).getPrizeOrRefound();

      await expect(pricelimit.connect(addrB1).getPrizeOrRefound()).to.be.revertedWith("No prize available");
      await expect(pricelimit.connect(addrA1).getPrizeOrRefound()).to.be.revertedWith("No prize available");

      expect(await token.balanceOf(addrA1.address)).to.equal(initialBalance + betA1.betWinValue);
      expect(await token.balanceOf(addrB1.address)).to.equal(initialBalance - betB1.betLossValue);
    });

    it("Test Range Binary Option", async function () {
      const { token, aggregator, addrA1, addrA2, addrB1 } = await loadFixture(deployTokenAndAggregatorAndCreateSomeAddressesWithTokensFixture);
      
      const Range = await ethers.getContractFactory("Range");

      const betExpirationTime = (await ethers.provider.getBlock("latest")).timestamp + 60*10; 

      const betA1 = {
        owner: addrA1.address,
        betLossValue: 40,
        betWinValue: 50
      }

      const betA2 = {
        owner: addrA2.address,
        betLossValue: 60,
        betWinValue: 50
      }

      const rangeA = {
        up: 1000010000,
        dn: 1000000000
      }      

      const betB1 = {
        owner: addrB1.address,
        betLossValue: 100,
        betWinValue: 100
      }

      const rangeB = {
        up: 1000030000,
        dn: 1000020000
      }

      const range = await Range.deploy(token.address, 
                                       aggregator.address,
                                       betExpirationTime,
                                       [[betA1, betA2], [betB1]],
                                       [rangeA, rangeB]);
      await range.deployed();

      await expect(range.create()).to.be.revertedWith("ERC20: insufficient allowance");

      await token.connect(addrA1).approve(range.address, betA1.betLossValue);
      await token.connect(addrA2).approve(range.address, betA2.betLossValue);
      await token.connect(addrB1).approve(range.address, betB1.betLossValue);

      await range.create();

      await expect(range.create()).to.be.revertedWith("Has already been created");
      await expect(range.claculatePrizes()).to.be.revertedWith("It isn't expired");

      await ethers.provider.send("evm_increaseTime", [3600]);

      await aggregator.setData(1, 
                              rangeB.dn+1, 
                              betExpirationTime+1,
                              betExpirationTime+1,
                              0)

      await range.claculatePrizes();

      await range.connect(addrB1).getPrizeOrRefound();

      await expect(range.connect(addrA1).getPrizeOrRefound()).to.be.revertedWith("No prize available");
      await expect(range.connect(addrA2).getPrizeOrRefound()).to.be.revertedWith("No prize available");
      await expect(range.connect(addrB1).getPrizeOrRefound()).to.be.revertedWith("No prize available");      
      
      expect(await token.balanceOf(addrB1.address)).to.equal(initialBalance + betB1.betWinValue);
      expect(await token.balanceOf(addrA1.address)).to.equal(initialBalance - betA1.betLossValue);
      expect(await token.balanceOf(addrA2.address)).to.equal(initialBalance - betA2.betLossValue);
    });

    it("Test Touch Binary Option", async function () {
      const { token, aggregator, addrA1, addrA2, addrB1, addrB2, addrC1 } = await loadFixture(deployTokenAndAggregatorAndCreateSomeAddressesWithTokensFixture);
      
      const Touch = await ethers.getContractFactory("Touch");

      const betExpirationTime = (await ethers.provider.getBlock("latest")).timestamp + 60*10; 

      const betA1 = {
        owner: addrA1.address,
        betLossValue: 40,
        betWinValue: 200
      }

      const betA2 = {
        owner: addrA2.address,
        betLossValue: 60,
        betWinValue: 200
      }

      const TouchA = {
        priceToTouch: 100000,
        betTouch: true
      }      

      const betB1 = {
        owner: addrB1.address,
        betLossValue: 100,
        betWinValue: 150
      }

      const betB2 = {
        owner: addrB2.address,
        betLossValue: 100,
        betWinValue: 150
      }

      const TouchB = {
        priceToTouch: 90000,
        betTouch: true
      }     

      const betC1 = {
        owner: addrC1.address,
        betLossValue: 200,
        betWinValue: 300
      }

      const TouchC = {
        priceToTouch: 0,
        betTouch: false
      }     

      await aggregator.setData(0,100001,0,0,0);

      await expect(Touch.deploy(token.address, 
                                aggregator.address,
                                betExpirationTime,
                                [[betA1, betA2], [betB1, betB2], [betC1]],
                                [TouchA, TouchB, TouchC])).
                                to.be.revertedWith("There is conflict between the touch configurations");

      await aggregator.setData(0,93000,0,0,0);

      const touch = await Touch.deploy(token.address, 
                                       aggregator.address,
                                       betExpirationTime,
                                       [[betA1, betA2], [betB1, betB2], [betC1]],
                                       [TouchA, TouchB, TouchC]);
      
      await touch.deployed();

      await expect(touch.create()).to.be.revertedWith("ERC20: insufficient allowance");

      const bets = [[addrA1, betA1], [addrA2, betA2], [addrB1, betB1], 
                    [addrB2, betB2], [addrC1, betC1]]

      await Promise.all(bets.map(async (bet) => {
        await token.connect(bet[0]).approve(touch.address, bet[1].betLossValue);
      }));

      await touch.create();

      await expect(touch.create()).to.be.revertedWith("Has already been created");

      await ethers.provider.send("evm_increaseTime", [3600]);

      await touch.claculatePrizes();

      await touch.connect(addrC1).getPrizeOrRefound();

      await Promise.all(bets.map(async (bet) => {
        expect(touch.connect(bet[0]).getPrizeOrRefound()).to.be.revertedWith("No prize available");
      }));

      
      expect(await token.balanceOf(addrC1.address)).to.equal(initialBalance + betC1.betWinValue);

      await Promise.all(bets.map(async (bet) => {
        if(bet[0]!=addrC1)
          expect(await token.balanceOf(bet[0].address)).to.equal(initialBalance - bet[1].betLossValue);
      }));
    });
  });
});