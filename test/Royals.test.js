const { expect } = require("chai");

describe("Royals", function () {
    let deployer, user1, user2;
    let royals;

    before(async function () {
        [deployer, user1, user2] = await hre.ethers.getSigners();
    });

    beforeEach(async function () {
        const Royals = await hre.ethers.getContractFactory("Royals");
        royals = await Royals.deploy("0x98a0227E99E7AF0f1f0D51746211a245c3B859c2", "0xC14E154076DF2FdC68c9DC5664ae39c3ea0fBE17");
        await royals.deployed();
        
        
    });

    describe("Minting", function (){
        it("should not be possible to mint while sale is off", async function(){
            await expect(
                royals.mint(1, [])
            ).to.be.revertedWith("Sale is not active");
        })
    })


    it("Should check constructor values", async function (){
        expect(await royals.name()).to.equal("Royals");
        expect(await royals.Habibiz()).to.equal("0x98a0227E99E7AF0f1f0D51746211a245c3B859c2");
        expect(await royals.oil()).to.equal("0xC14E154076DF2FdC68c9DC5664ae39c3ea0fBE17");
        expect(await royals.totalSupplyLeft()).to.equal(300);
        expect(await royals.BatchSizeLeft()).to.equal(0);
    })

    it("Should set maxMintPerWallet", async function() {
        royals.setMaxMintPerWallet(5);
        expect(await royals.maxMintPerWallet()).to.equal(5);
        royals.setMaxMintPerWallet(2);
        expect(await royals.maxMintPerWallet()).to.equal(2);
    })

    it("should turn sale is off then, turn on then back off", async function (){
        expect(await royals.saleState()).to.equal(0);
        await royals.setSaleState(1);
        expect(await royals.saleState()).to.equal(1);
        await royals.setSaleState(0);
        expect(await royals.saleState()).to.equal(0);
    })

    it("should return correct initial OIL address +  set new address", async function () {
        expect(await royals.oil()).to.equal("0xC14E154076DF2FdC68c9DC5664ae39c3ea0fBE17");
        await royals.setOilAddress("0x98a0227E99E7AF0f1f0D51746211a245c3B859c2");
        expect(await royals.oil()).to.equal("0x98a0227E99E7AF0f1f0D51746211a245c3B859c2");
    })
    
    it("should verify batch size initializing to 0 and changing it", async function() {
        expect(await royals.BatchSizeLeft()).to.equal(0);
        await royals.setBatchSize(100);
        expect(await royals.BatchSizeLeft()).to.equal(100);
        await royals.setBatchSize(300);
        expect(await royals.BatchSizeLeft()).to.equal(300);
        expect(royals.setBatchSize(400)).to.be.revertedWith('We have reached batch limit');
      
    })

});