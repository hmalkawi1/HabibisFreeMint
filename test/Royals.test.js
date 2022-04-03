const { expect } = require("chai");

describe("Royals", function () {
    let deployer, user1, user2;
    let royals;
    let habibz;
    let oil;
    let mintedHabibzArr = [];
    before(async function () {
        [deployer, user1, user2] = await hre.ethers.getSigners();

        const Habibz = await hre.ethers.getContractFactory("Habibi");
        habibz = await Habibz.deploy("habibz", "hbz", "", "");
        await habibz.setMaxMintAmount(2000);
        await habibz.mint(24);
        for (i = 0; i < 8; i++) {
            mintedHabibzArr.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
        }

        const OIL = await hre.ethers.getContractFactory("Oil");
        oil = await OIL.deploy();
        //console.log(deployer.address);
        // await oil.setRuler(deployer.address);
        await oil.initialize(habibz.address, "0x0000000000000000000000000000000000000000");
        // Allow our deploy oil to have access to our habibz
        await habibz.setApprovalForAll(oil.address, true);
        await habibz.isApprovedForAll(deployer.address, oil.address);
        // console.log(await oil.habibi());
        // console.log(await oil.habibizOfStaker(deployer.address));
    });

    beforeEach(async function () {
        const Royals = await hre.ethers.getContractFactory("Royals");
        royals = await Royals.deploy(habibz.address, oil.address, "", "", 3);
        await royals.deployed();
        // const oil = await hre.ethers.getContractFactory("OIL");
        // oil = await OIL.deploy();
        // await oil.deployed();
    });

    describe("Minting Failure", function () {
        it("Should not be possible to mint while sale is off", async function () {
            await expect(royals.mint([], [])).to.be.revertedWith("Sale is not active");
        });
        it("Should not be possible to mint when i'm not whitelisted", async function () {
            await royals.setSaleState(1);
            await expect(royals.mint([], [])).to.be.revertedWith("This address is not whitelisted");
        });

        it("Should not be possible to mint when I burn less than 8 habibz", async function () {
            await royals.setSaleState(2);
            await expect(royals.mint([], [])).to.be.revertedWith("You must burn atleast 8 habibz");
        });

        it("Should not be possible to mint when I don't burn multiples of 8 habibz", async function () {
            await royals.setSaleState(2);
            await royals.setBatchSize(15);
            let testArr = [];
            for (i = 0; i < 11; i++) {
                testArr.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
            }
            await expect(royals.mint(testArr, [])).to.be.revertedWith("You must burn multiples of 8 habibz only");
        });

        it("Should not be possible to mint when minting would exceed BatchSizeLeft", async function () {
            await royals.setSaleState(2);
            await royals.setBatchSize(1);
            let testArr = [];
            for (i = 0; i < 16; i++) {
                testArr.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
            }
            await expect(royals.mint(testArr, [])).to.be.revertedWith("Theres none left in this batch to mint");
        });

        it("Should not be possible to mint when minting would exceed total supply", async function () {
            await royals.setSaleState(2);
            await royals.setBatchSize(2);
            await royals.setTotalSupplyLeft(1);
            let testArr = [];
            for (i = 0; i < 16; i++) {
                testArr.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
            }
            await expect(royals.mint(testArr, [])).to.be.revertedWith("Theres no more Royals to mint");
        });

        it("Should not be possible to mint when maximum allowable mints has been reached", async function () {
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setAux(deployer.address, 3);
            await royals.setMaxMintPerWallet(3);
            await expect(royals.mint(mintedHabibzArr, [])).to.be.revertedWith("You do not have enough mints available");
        });

        it("Should not be possible to mint when minting would exceed maximum amount of allowable mints per wallet", async function () {
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setAux(deployer.address, 2);
            await royals.setMaxMintPerWallet(3);
            let testArr = [];
            for (i = 0; i < 16; i++) {
                testArr.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
            }
            await expect(royals.mint(testArr, [])).to.be.revertedWith("Minting would exceed maximum allowable mints");
        });

        it("Should fail if there are not enough royals left to mint", async function (){
            oil.setRoyalsAddress(royals.address);
            await royals.setBatchSize(10);
            await royals.setTotalSupplyLeft(8);
            await royals.setMaxMintPerWallet(300);
            await royals.setSaleState(2);
            await habibz.setMaxMintAmount(800);
            await habibz.setNftPerAddressLimit(800);
            await habibz.mint(80);
            let habibzToBeBurned = [];
            for (i = 0; i < 80; i++) {
                habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
            }
            await oil.stake(habibzToBeBurned);
            expect(royals.mint(habibzToBeBurned, [])).to.be.revertedWith("Theres no more Royals to mint or you have requested a higher mint than whats left in the supply");
            
        });

        // it("Should Fail if input TokenIds are not unique", async function () {
        //     oil.setRoyalsAddress(royals.address);
        //     await royals.setSaleState(2);
        //     await royals.setBatchSize(10);
        //     await habibz.mint(24);
        //     await royals.setMaxMintPerWallet(3);
        //     let habibzToBeBurned = [26, 27, 28, 29, 22, 26, 30, 26];

        //     await oil.stake([26, 27, 30]);
        //     expect(royals.mint(habibzToBeBurned, [])).to.be.revertedWith("Atleast one of your submitted habibz is not unique");
        // });
    });
    describe("Minting Success", function () {
        it("Should successfully mint 2 after burning exactly 16 staked habibz", async function () {
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setMaxMintPerWallet(4);
            let habibzToBeBurned = [];
            for (i = 0; i < 8; i++) {
                habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
            }
            await oil.stake(habibzToBeBurned);
            await royals.mint(habibzToBeBurned, []);
            expect(await royals.balanceOf(deployer.address)).to.equal(1);
        });

        it("Should successfully mint 5 when there is exactly 5 total supply left", async function () {
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setTotalSupplyLeft(5);
            await habibz.mint(40);
            await royals.setMaxMintPerWallet(10);
            await habibz.setNftPerAddressLimit(200);
            let habibzToBeBurned = [];
            for (i = 0; i < 40; i++) {
                habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
            }
            await oil.stake(habibzToBeBurned);
            await royals.mint(habibzToBeBurned, []);
            expect(royals.mint(habibzToBeBurned, [])).to.be.revertedWith("Theres no more Royals to mint");
        });

        // it("Should make sure the correct frozen habibis are added to the public array of frozen habibis", async function () {
        //     oil.setRoyalsAddress(royals.address);
        //     await habibz.mint(24);
        //     await royals.setSaleState(2);
        //     await royals.setBatchSize(10);
        //     await royals.setMaxMintPerWallet(3);
        //     let habibzToBeBurned = [];
        //     for (i = 0; i < 24; i++) {
        //         habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
        //     }
        //     await oil.stake(habibzToBeBurned);
        //     await royals.mint(habibzToBeBurned, []);
        //     const frozenHabibiz = await royals.getFrozenHabibiz();
        //     expect(frozenHabibiz.length).to.eq(24);
        // });
    });

    it("tokens should run from 1-10", async function (){
        oil.setRoyalsAddress(royals.address);
        await royals.setBatchSize(10);
        await royals.setTotalSupplyLeft(8);
        await royals.setMaxMintPerWallet(300);
        await royals.setSaleState(2);
        await habibz.setMaxMintAmount(200);
        await habibz.setNftPerAddressLimit(200);
        await habibz.mint(80);
        let habibzToBeBurned = [];
        for (i = 0; i < 64; i++) {
            habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
        }
        await oil.stake(habibzToBeBurned);
        await royals.mint(habibzToBeBurned, []);
        console.log(await habibz.walletOfOwner(deployer.address));
        console.log("Royals by owner:")
        console.log(await royals.balanceOf(deployer.address));
        expect(await royals.balanceOf(deployer.address)).to.equal(8);

    });

    it("Should check constructor values", async function () {
        expect(await royals.name()).to.equal("Royals");
        expect(await royals.Habibiz()).to.equal(habibz.address);
        expect(await royals.oil()).to.equal(oil.address);
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
        expect(await royals.oil()).to.equal(oil.address);
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

});
