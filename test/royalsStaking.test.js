const { expect } = require("chai");

describe("Royals", function () {
    let deployer, user1, user2;
    let royals;
    let habibz;
    let oil;
    let mintedHabibzArr = [];
    before(async function () {
        [deployer, user1, user2] = await hre.ethers.getSigners();
        const OIL = await hre.ethers.getContractFactory("Oil");
        oil = await OIL.deploy();
    });

    beforeEach(async function () {
        const Habibz = await hre.ethers.getContractFactory("Habibi");
        habibz = await Habibz.deploy("habibz", "hbz", "", "");
        await habibz.setMaxMintAmount(2000);

        await habibz.setApprovalForAll(oil.address, true);
        await habibz.isApprovedForAll(deployer.address, oil.address);
        await oil.initialize(habibz.address, "0x0000000000000000000000000000000000000000");
        const Royals = await hre.ethers.getContractFactory("Royals");
        royals = await Royals.deploy(habibz.address, oil.address, "", "", 3);
        await royals.deployed();
    });

    describe("royals Of Staker", function () {
        it("should return length 0 if none is staked", async function(){
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setMaxMintPerWallet(4);
            await habibz.mint(8);
            let habibzToBeBurned = [];
            for (i = 0; i < 8; i++) {
                habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
            }
            await oil.stake(habibzToBeBurned);
            await royals.mint(habibzToBeBurned, []);
            expect(await royals.balanceOf(deployer.address)).to.equal(1);

            //console.log(await royals.walletOfOwner(deployer.address).toNumber());
            console.log(await royals.ownerOf(0));
            //await oil.stakeRoyals([0]);
            
            //expect(await royals.balanceOf(deployer.address)).to.equal(0);

            //expect(await oil.royalsOfStaker(deployer.address).length).to.equal(1);
        })
    })
});