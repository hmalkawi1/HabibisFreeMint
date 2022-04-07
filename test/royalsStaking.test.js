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
        it("walletOfOwner test", async function(){
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setMaxMintPerWallet(4);
            await habibz.mint(16);
            let habibzToBeBurned = [];
            for (i = 0; i < 16; i++) {
                habibzToBeBurned.push(await habibz.tokenOfOwnerByIndex(deployer.address, i));
            }
            await oil.stake(habibzToBeBurned);
            await royals.mint(habibzToBeBurned, []);
            
            expect((await royals.walletOfOwner(deployer.address)).length).to.equal(2);
            
            
           
            const RoycontractFromUser = await hre.ethers.getContractAt(
                "Royals",
                royals.address,
                user1
            );
            const HabcontractFromUser = await hre.ethers.getContractAt(
                "Habibi",
                habibz.address,
                user1
            );
            const OilcontractFromUser = await hre.ethers.getContractAt(
                "Oil",
                oil.address,
                user1
            );
            await HabcontractFromUser.mint(3);

         
            await royals.setAmountRequiredToBurn(1);
            let habibzToBeBurned3 = [];
            for (i = 0; i < 3; i++) {
                habibzToBeBurned3.push(await HabcontractFromUser.tokenOfOwnerByIndex(user1.address, i));
            }
            HabcontractFromUser.setApprovalForAll(oil.address,true);
            await OilcontractFromUser.stake(habibzToBeBurned3);
            await RoycontractFromUser.mint(habibzToBeBurned3, []);
            expect((await royals.walletOfOwner(user1.address)).length).to.equal(3);

        })
        it("should return length 0 if none is staked", async function(){
            let arr = [];
            arr = await oil.royalsOfStaker(deployer.address);
            expect(arr.length).to.eq(0);
        })

        it("should stake and remove Royal from users wallet + should show owned by OIL", async function(){
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

            await royals.approve(oil.address, 1);
            await oil.stakeRoyals([1]);
            expect((await royals.walletOfOwner(deployer.address)).length).to.eq(0);
            expect((await royals.walletOfOwner(oil.address)).length).to.eq(1);
        });

        
        it.only("should unstake Royal from Oil by ID", async function(){
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

            let compare = []
            compare = await royals.walletOfOwner(deployer.address);
            await royals.approve(oil.address, 1);
            await oil.stakeRoyals(await royals.walletOfOwner(deployer.address));

     
            expect((await royals.walletOfOwner(oil.address)).length).to.eq(1);
            
            expect ((await oil.royalsOfStaker(deployer.address)).length).to.equal(1);
           

            await oil.unstakeRoyalsByIds([1]);
            expect((await oil.royalsOfStaker(deployer.address)).length).to.equal(0);
            
        });

        it("should unstakeAll", async function(){
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setMaxMintPerWallet(4);


            const RoycontractFromUser = await hre.ethers.getContractAt(
                "Royals",
                royals.address,
                user1
            );
            const HabcontractFromUser = await hre.ethers.getContractAt(
                "Habibi",
                habibz.address,
                user1
            );
            const OilcontractFromUser = await hre.ethers.getContractAt(
                "Oil",
                oil.address,
                user1
            );

            await HabcontractFromUser.mint(3);
            let habibzToBeBurned = [];
            for (i = 0; i < 3; i++) {
                habibzToBeBurned.push(await HabcontractFromUser.tokenOfOwnerByIndex(user1.address, i));
            }
            HabcontractFromUser.setApprovalForAll(oil.address,true)
            await royals.setAmountRequiredToBurn(1);
            await OilcontractFromUser.stake(habibzToBeBurned);
            await RoycontractFromUser.mint(habibzToBeBurned, []);
            let test = [];
            test = await RoycontractFromUser.walletOfOwner(user1.address);
            //console.log(test);
            await RoycontractFromUser.setApprovalForAll(oil.address, true);
            await OilcontractFromUser.stakeRoyals(await RoycontractFromUser.walletOfOwner(user1.address));
            //console.log(await OilcontractFromUser.royalsOfStaker(user1.address));
            expect((await OilcontractFromUser.royalsOfStaker(user1.address)).length).to.be.equal(test.length);
            await OilcontractFromUser.unstakeAllRoyals();
            expect((await OilcontractFromUser.royalsOfStaker(user1.address)).length).to.be.equal(0);
            //console.log(await RoycontractFromUser.walletOfOwner(user1.address));
            //expect(await RoycontractFromUser.walletOfOwner(user1.address)).to.be.equal(test);
            
        });
        
        it("Should calculate rewards correctly for 0% bonus for 3 staked", async function(){
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setMaxMintPerWallet(4);


            const RoycontractFromUser = await hre.ethers.getContractAt(
                "Royals",
                royals.address,
                user1
            );
            const HabcontractFromUser = await hre.ethers.getContractAt(
                "Habibi",
                habibz.address,
                user1
            );
            const OilcontractFromUser = await hre.ethers.getContractAt(
                "Oil",
                oil.address,
                user1
            );

            await HabcontractFromUser.mint(3);
            let habibzToBeBurned = [];
            for (i = 0; i < 3; i++) {
                habibzToBeBurned.push(await HabcontractFromUser.tokenOfOwnerByIndex(user1.address, i));
            }
            HabcontractFromUser.setApprovalForAll(oil.address,true)
            await royals.setAmountRequiredToBurn(1);
            await OilcontractFromUser.stake(habibzToBeBurned);
            await RoycontractFromUser.mint(habibzToBeBurned, []);

            

            let balance = await OilcontractFromUser.balanceOf(user1.address);
            console.log("Oil Balance before unstaking: %s", ethers.utils.formatEther(balance));

            await RoycontractFromUser.setApprovalForAll(oil.address, true);
            await OilcontractFromUser.stakeRoyals(await RoycontractFromUser.walletOfOwner(user1.address));
            //============================================================//
            const sevenDays = 7 * 24 * 60 * 60;
            const blockNumBefore = await ethers.provider.getBlockNumber();
            const blockBefore = await ethers.provider.getBlock(blockNumBefore);
            const timestampBefore = blockBefore.timestamp;
            await ethers.provider.send('evm_increaseTime', [sevenDays]);
            await ethers.provider.send('evm_mine');
            const blockNumAfter = await ethers.provider.getBlockNumber();
            const blockAfter = await ethers.provider.getBlock(blockNumAfter);
            const timestampAfter = blockAfter.timestamp;
            expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
            expect(timestampAfter).to.be.equal(timestampBefore + sevenDays);
            //============================================================//
            console.log(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address)));
            lessThan30 = 315000.0
            expect(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address))).to.eq(lessThan30.toFixed(1));
           
        })

        it("Should calculate rewards correctly for 15% bonus for 3 staked", async function(){
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setMaxMintPerWallet(4);


            const RoycontractFromUser = await hre.ethers.getContractAt(
                "Royals",
                royals.address,
                user1
            );
            const HabcontractFromUser = await hre.ethers.getContractAt(
                "Habibi",
                habibz.address,
                user1
            );
            const OilcontractFromUser = await hre.ethers.getContractAt(
                "Oil",
                oil.address,
                user1
            );

            await HabcontractFromUser.mint(3);
            let habibzToBeBurned = [];
            for (i = 0; i < 3; i++) {
                habibzToBeBurned.push(await HabcontractFromUser.tokenOfOwnerByIndex(user1.address, i));
            }
            HabcontractFromUser.setApprovalForAll(oil.address,true)
            await royals.setAmountRequiredToBurn(1);
            await OilcontractFromUser.stake(habibzToBeBurned);
            await RoycontractFromUser.mint(habibzToBeBurned, []);

            

            let balance = await OilcontractFromUser.balanceOf(user1.address);
            console.log("Oil Balance before unstaking: %s", ethers.utils.formatEther(balance));

            await RoycontractFromUser.setApprovalForAll(oil.address, true);
            await OilcontractFromUser.stakeRoyals(await RoycontractFromUser.walletOfOwner(user1.address));
            //============================================================//
            const oneMonth = 30 * 24 * 60 * 60;
            const blockNumBefore = await ethers.provider.getBlockNumber();
            const blockBefore = await ethers.provider.getBlock(blockNumBefore);
            const timestampBefore = blockBefore.timestamp;
            await ethers.provider.send('evm_increaseTime', [oneMonth]);
            await ethers.provider.send('evm_mine');
            const blockNumAfter = await ethers.provider.getBlockNumber();
            const blockAfter = await ethers.provider.getBlock(blockNumAfter);
            const timestampAfter = blockAfter.timestamp;
            expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
            expect(timestampAfter).to.be.equal(timestampBefore + oneMonth);
            //============================================================//
            console.log(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address)));
            thirty = 1552500.0
            expect(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address))).to.eq(thirty.toFixed(1));
           
        })

        it("Should calculate rewards correctly for 30% bonus for 3 staked", async function(){
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setMaxMintPerWallet(4);

            const RoycontractFromUser = await hre.ethers.getContractAt(
                "Royals",
                royals.address,
                user1
            );
            const HabcontractFromUser = await hre.ethers.getContractAt(
                "Habibi",
                habibz.address,
                user1
            );
            const OilcontractFromUser = await hre.ethers.getContractAt(
                "Oil",
                oil.address,
                user1
            );

            await HabcontractFromUser.mint(3);
            let habibzToBeBurned = [];
            for (i = 0; i < 3; i++) {
                habibzToBeBurned.push(await HabcontractFromUser.tokenOfOwnerByIndex(user1.address, i));
            }
            HabcontractFromUser.setApprovalForAll(oil.address,true)
            await royals.setAmountRequiredToBurn(1);
            await OilcontractFromUser.stake(habibzToBeBurned);
            await RoycontractFromUser.mint(habibzToBeBurned, []);

            

            let balance = await OilcontractFromUser.balanceOf(user1.address);
            console.log("Oil Balance before unstaking: %s", ethers.utils.formatEther(balance));

            await RoycontractFromUser.setApprovalForAll(oil.address, true);
            await OilcontractFromUser.stakeRoyals(await RoycontractFromUser.walletOfOwner(user1.address));
            //============================================================//
            const twoMonth = 60 * 24 * 60 * 60;
            const blockNumBefore = await ethers.provider.getBlockNumber();
            const blockBefore = await ethers.provider.getBlock(blockNumBefore);
            const timestampBefore = blockBefore.timestamp;
            await ethers.provider.send('evm_increaseTime', [twoMonth]);
            await ethers.provider.send('evm_mine');
            const blockNumAfter = await ethers.provider.getBlockNumber();
            const blockAfter = await ethers.provider.getBlock(blockNumAfter);
            const timestampAfter = blockAfter.timestamp;
            expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
            expect(timestampAfter).to.be.equal(timestampBefore + twoMonth);
            //============================================================//
            console.log(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address)));
            sixty = 3510000.0
            expect(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address))).to.eq(sixty.toFixed(1));
        })

        it("Should calculate rewards correctly for 100% bonus for 3 staked", async function(){
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setMaxMintPerWallet(4);

            const RoycontractFromUser = await hre.ethers.getContractAt(
                "Royals",
                royals.address,
                user1
            );
            const HabcontractFromUser = await hre.ethers.getContractAt(
                "Habibi",
                habibz.address,
                user1
            );
            const OilcontractFromUser = await hre.ethers.getContractAt(
                "Oil",
                oil.address,
                user1
            );

            await HabcontractFromUser.mint(3);
            let habibzToBeBurned = [];
            for (i = 0; i < 3; i++) {
                habibzToBeBurned.push(await HabcontractFromUser.tokenOfOwnerByIndex(user1.address, i));
            }
            HabcontractFromUser.setApprovalForAll(oil.address,true)
            await royals.setAmountRequiredToBurn(1);
            await OilcontractFromUser.stake(habibzToBeBurned);
            await RoycontractFromUser.mint(habibzToBeBurned, []);

            

            let balance = await OilcontractFromUser.balanceOf(user1.address);
            console.log("Oil Balance before unstaking: %s", ethers.utils.formatEther(balance));

            await RoycontractFromUser.setApprovalForAll(oil.address, true);
            await OilcontractFromUser.stakeRoyals(await RoycontractFromUser.walletOfOwner(user1.address));
            //============================================================//
            const threeMonths = 90 * 24 * 60 * 60;
            const blockNumBefore = await ethers.provider.getBlockNumber();
            const blockBefore = await ethers.provider.getBlock(blockNumBefore);
            const timestampBefore = blockBefore.timestamp;
            await ethers.provider.send('evm_increaseTime', [threeMonths]);
            await ethers.provider.send('evm_mine');
            const blockNumAfter = await ethers.provider.getBlockNumber();
            const blockAfter = await ethers.provider.getBlock(blockNumAfter);
            const timestampAfter = blockAfter.timestamp;
            expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
            expect(timestampAfter).to.be.equal(timestampBefore + threeMonths);
            //============================================================//
            console.log(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address)));
            ninty = 8100000.0
            expect(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address))).to.eq(ninty.toFixed(1));
        })

        it("Should calculate rewards correctly for 0% bonus for 1 staked", async function(){
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setMaxMintPerWallet(4);


            const RoycontractFromUser = await hre.ethers.getContractAt(
                "Royals",
                royals.address,
                user1
            );
            const HabcontractFromUser = await hre.ethers.getContractAt(
                "Habibi",
                habibz.address,
                user1
            );
            const OilcontractFromUser = await hre.ethers.getContractAt(
                "Oil",
                oil.address,
                user1
            );

            await HabcontractFromUser.mint(3);
            let habibzToBeBurned = [];
            for (i = 0; i < 3; i++) {
                habibzToBeBurned.push(await HabcontractFromUser.tokenOfOwnerByIndex(user1.address, i));
            }
            HabcontractFromUser.setApprovalForAll(oil.address,true)
            await royals.setAmountRequiredToBurn(3);
            await OilcontractFromUser.stake(habibzToBeBurned);
            await RoycontractFromUser.mint(habibzToBeBurned, []);

            

            let balance = await OilcontractFromUser.balanceOf(user1.address);
            console.log("Oil Balance before unstaking: %s", ethers.utils.formatEther(balance));

            await RoycontractFromUser.setApprovalForAll(oil.address, true);
            await OilcontractFromUser.stakeRoyals(await RoycontractFromUser.walletOfOwner(user1.address));
            //============================================================//
            const sevenDays = 7 * 24 * 60 * 60;
            const blockNumBefore = await ethers.provider.getBlockNumber();
            const blockBefore = await ethers.provider.getBlock(blockNumBefore);
            const timestampBefore = blockBefore.timestamp;
            await ethers.provider.send('evm_increaseTime', [sevenDays]);
            await ethers.provider.send('evm_mine');
            const blockNumAfter = await ethers.provider.getBlockNumber();
            const blockAfter = await ethers.provider.getBlock(blockNumAfter);
            const timestampAfter = blockAfter.timestamp;
            expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
            expect(timestampAfter).to.be.equal(timestampBefore + sevenDays);
            //============================================================//
            console.log(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address)));
            lessThan30 = 84000.0
            expect(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address))).to.eq(lessThan30.toFixed(1));
           
        })

        it("Should calculate rewards correctly for 15% bonus for 1 staked", async function(){
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setMaxMintPerWallet(4);


            const RoycontractFromUser = await hre.ethers.getContractAt(
                "Royals",
                royals.address,
                user1
            );
            const HabcontractFromUser = await hre.ethers.getContractAt(
                "Habibi",
                habibz.address,
                user1
            );
            const OilcontractFromUser = await hre.ethers.getContractAt(
                "Oil",
                oil.address,
                user1
            );

            await HabcontractFromUser.mint(3);
            let habibzToBeBurned = [];
            for (i = 0; i < 3; i++) {
                habibzToBeBurned.push(await HabcontractFromUser.tokenOfOwnerByIndex(user1.address, i));
            }
            HabcontractFromUser.setApprovalForAll(oil.address,true)
            await royals.setAmountRequiredToBurn(3);
            await OilcontractFromUser.stake(habibzToBeBurned);
            await RoycontractFromUser.mint(habibzToBeBurned, []);

            

            let balance = await OilcontractFromUser.balanceOf(user1.address);
            console.log("Oil Balance before unstaking: %s", ethers.utils.formatEther(balance));

            await RoycontractFromUser.setApprovalForAll(oil.address, true);
            await OilcontractFromUser.stakeRoyals(await RoycontractFromUser.walletOfOwner(user1.address));
            //============================================================//
            const oneMonth = 30 * 24 * 60 * 60;
            const blockNumBefore = await ethers.provider.getBlockNumber();
            const blockBefore = await ethers.provider.getBlock(blockNumBefore);
            const timestampBefore = blockBefore.timestamp;
            await ethers.provider.send('evm_increaseTime', [oneMonth]);
            await ethers.provider.send('evm_mine');
            const blockNumAfter = await ethers.provider.getBlockNumber();
            const blockAfter = await ethers.provider.getBlock(blockNumAfter);
            const timestampAfter = blockAfter.timestamp;
            expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
            expect(timestampAfter).to.be.equal(timestampBefore + oneMonth);
            //============================================================//
            console.log(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address)));
            thirty = 414000
            expect(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address))).to.eq(thirty.toFixed(1));
           
        })

        it("Should calculate rewards correctly for 30% bonus for 1 staked", async function(){
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setMaxMintPerWallet(4);

            const RoycontractFromUser = await hre.ethers.getContractAt(
                "Royals",
                royals.address,
                user1
            );
            const HabcontractFromUser = await hre.ethers.getContractAt(
                "Habibi",
                habibz.address,
                user1
            );
            const OilcontractFromUser = await hre.ethers.getContractAt(
                "Oil",
                oil.address,
                user1
            );

            await HabcontractFromUser.mint(3);
            let habibzToBeBurned = [];
            for (i = 0; i < 3; i++) {
                habibzToBeBurned.push(await HabcontractFromUser.tokenOfOwnerByIndex(user1.address, i));
            }
            HabcontractFromUser.setApprovalForAll(oil.address,true)
            await royals.setAmountRequiredToBurn(3);
            await OilcontractFromUser.stake(habibzToBeBurned);
            await RoycontractFromUser.mint(habibzToBeBurned, []);

            

            let balance = await OilcontractFromUser.balanceOf(user1.address);
            console.log("Oil Balance before unstaking: %s", ethers.utils.formatEther(balance));

            await RoycontractFromUser.setApprovalForAll(oil.address, true);
            await OilcontractFromUser.stakeRoyals(await RoycontractFromUser.walletOfOwner(user1.address));
            //============================================================//
            const twoMonth = 60 * 24 * 60 * 60;
            const blockNumBefore = await ethers.provider.getBlockNumber();
            const blockBefore = await ethers.provider.getBlock(blockNumBefore);
            const timestampBefore = blockBefore.timestamp;
            await ethers.provider.send('evm_increaseTime', [twoMonth]);
            await ethers.provider.send('evm_mine');
            const blockNumAfter = await ethers.provider.getBlockNumber();
            const blockAfter = await ethers.provider.getBlock(blockNumAfter);
            const timestampAfter = blockAfter.timestamp;
            expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
            expect(timestampAfter).to.be.equal(timestampBefore + twoMonth);
            //============================================================//
            console.log(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address)));
            sixty = 936000
            expect(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address))).to.eq(sixty.toFixed(1));
        })

        it("Should calculate rewards correctly for 100% bonus for 1 staked and claims correct amount", async function(){
            oil.setRoyalsAddress(royals.address);
            await royals.setSaleState(2);
            await royals.setBatchSize(10);
            await royals.setMaxMintPerWallet(4);

            const RoycontractFromUser = await hre.ethers.getContractAt(
                "Royals",
                royals.address,
                user1
            );
            const HabcontractFromUser = await hre.ethers.getContractAt(
                "Habibi",
                habibz.address,
                user1
            );
            const OilcontractFromUser = await hre.ethers.getContractAt(
                "Oil",
                oil.address,
                user1
            );

            await HabcontractFromUser.mint(3);
            let habibzToBeBurned = [];
            for (i = 0; i < 3; i++) {
                habibzToBeBurned.push(await HabcontractFromUser.tokenOfOwnerByIndex(user1.address, i));
            }
            HabcontractFromUser.setApprovalForAll(oil.address,true)
            await royals.setAmountRequiredToBurn(3);
            await OilcontractFromUser.stake(habibzToBeBurned);
            await RoycontractFromUser.mint(habibzToBeBurned, []);

            

            let balance = await OilcontractFromUser.balanceOf(user1.address);
            console.log("Oil Balance before unstaking: %s", ethers.utils.formatEther(balance));

            await RoycontractFromUser.setApprovalForAll(oil.address, true);
            await OilcontractFromUser.stakeRoyals(await RoycontractFromUser.walletOfOwner(user1.address));
            //============================================================//
            const threeMonths = 90 * 24 * 60 * 60;
            const blockNumBefore = await ethers.provider.getBlockNumber();
            const blockBefore = await ethers.provider.getBlock(blockNumBefore);
            const timestampBefore = blockBefore.timestamp;
            await ethers.provider.send('evm_increaseTime', [threeMonths]);
            await ethers.provider.send('evm_mine');
            const blockNumAfter = await ethers.provider.getBlockNumber();
            const blockAfter = await ethers.provider.getBlock(blockNumAfter);
            const timestampAfter = blockAfter.timestamp;
            expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
            expect(timestampAfter).to.be.equal(timestampBefore + threeMonths);
            //============================================================//
            
            console.log("Oil rewards: %s",ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address)));
            ninty = 2160000.0
            expect(ethers.utils.formatEther(await OilcontractFromUser.calculateRoyalsOilRewards(user1.address))).to.eq(ninty.toFixed(1));

            expectedBalance = balance + ninty;

            await OilcontractFromUser.claimRoyal()
            console.log(ethers.utils.formatEther(await OilcontractFromUser.balanceOf(user1.address)) / 1)
            expect(ethers.utils.formatEther(await OilcontractFromUser.balanceOf(user1.address))).to.equal(expectedBalance)
        })



    })
});