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

        // const oil = await hre.ethers.getContractFactory("OIL");
        // oil = await OIL.deploy();
        // await oil.deployed();
    });

    describe("Minting", function () {
        it("Should not be possible to mint while sale is off", async function () {
            await expect(royals.mint([])).to.be.revertedWith("Sale is not active");
        });

        it("Should not be possible to mint over existing batch supply", async function () {
            await royals.setSaleState(1);
            await royals.setAux(deployer.address, 1); 
            await expect(royals.mint([])).to.be.revertedWith("Theres none left in this batch to mint");
        });

        it("Should not be possible to mint over what your allowed to", async function () {
            await royals.setSaleState(1);
            await royals.setBatchSize(15);
            //await royals.setMaxMintPerWallet(2);
            await expect(royals.mint([])).to.be.revertedWith("You do not have enough mints available");
        });

        it("should mint 1", async function(){
            await royals.setSaleState(1);
            //await royals.setMaxMintPerWallet(3);

            const contractFromUser = await hre.ethers.getContractAt(
                "Royals",
                royals.address,
                deployer
            );
            const prevTotalBalance = await royals.totalSupplyLeft();

            await royals.setAux(deployer.address, 1); 
            await royals.setBatchSize(15);

            await contractFromUser.mint([]);

            console.log( (await royals.totalSupplyLeft()).toNumber());

            expect((await royals.totalSupplyLeft()).toNumber()).to.equal(
                prevTotalBalance.sub(1).toNumber()
            );

        });

    });

    it("Should check constructor values", async function () {
        expect(await royals.name()).to.equal("Royals");
        expect(await royals.Habibiz()).to.equal("0x98a0227E99E7AF0f1f0D51746211a245c3B859c2");
        expect(await royals.oil()).to.equal("0xC14E154076DF2FdC68c9DC5664ae39c3ea0fBE17");
        expect(await royals.totalSupplyLeft()).to.equal(300);
        expect(await royals.BatchSizeLeft()).to.equal(0);
    });

    it("Should set maxMintPerWallet", async function () {
        royals.setMaxMintPerWallet(5);
        expect(await royals.maxMintPerWallet()).to.equal(5);
        royals.setMaxMintPerWallet(2);
        expect(await royals.maxMintPerWallet()).to.equal(2);
    });

    it("Should turn sale is off then, turn on then back off", async function () {
        expect(await royals.saleState()).to.equal(0);
        await royals.setSaleState(1);
        expect(await royals.saleState()).to.equal(1);
        await royals.setSaleState(0);
        expect(await royals.saleState()).to.equal(0);
    });

    it("Should return correct initial OIL address +  set new address", async function () {
        expect(await royals.oil()).to.equal("0xC14E154076DF2FdC68c9DC5664ae39c3ea0fBE17");
        await royals.setOilAddress("0x98a0227E99E7AF0f1f0D51746211a245c3B859c2");
        expect(await royals.oil()).to.equal("0x98a0227E99E7AF0f1f0D51746211a245c3B859c2");
    });

    it("Should verify batch size initializing to 0 and changing it", async function () {
        expect(await royals.BatchSizeLeft()).to.equal(0);
        await royals.setBatchSize(100);
        expect(await royals.BatchSizeLeft()).to.equal(100);
        await royals.setBatchSize(300);
        expect(await royals.BatchSizeLeft()).to.equal(300);
        expect(royals.setBatchSize(400)).to.be.revertedWith("We have reached batch limit");
    });

    it("Should return default base extension of json", async function () {
        expect(await royals.baseExtension()).to.equal(".json");
    });

    it("Should return updated base extension of png", async function () {
        await royals.setBaseExtension(".png");
        expect(await royals.baseExtension()).to.equal(".png");
    });
    // setBaseExtension
    // burn
    //
});
