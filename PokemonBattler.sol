// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PKMNBATTLER is ERC721, Ownable {
    //status of the battle
    enum BattleStatus {
        Available,
        Requested,
        Ongoing,
        Completed
    }

    struct Attack {
        uint256 damage;
        uint256 accuracy;
        string name;
    }

    struct Status {
        uint256 hp;
        uint256 attackMod;
        uint256 defenseMod;
        string name;
    }

    struct Pokemon {
        Attack move1;
        Attack move2;
        Attack move3;
        Attack move4;
        Status status;
    }

    //current battle
    struct Battle {
        //to find out the attacking pokemon
        uint256 turnCounter;

        //to find out the current state of the battle if it's ongoing completed or not
        BattleStatus status;
        address addr_challenger;
        address addr_challenged;
        uint256 pokemon_challenger;
        uint256 pokemon_challenged;

        //local copy of the hp of the pokemon
        int256 challengerHP;
        int256 challengedHP;
    }

    //the battle challege is sent to the challenger
    struct BattleChallenge {
        BattleStatus status;
        uint256 challengeId;
    }

    //pokemon data NFT array
    Pokemon[] public s_Pokemons;

    //owner of pokemon nfts
    mapping ( address => uint256[] ) public s_PokemonOwners;

    //check the current status of a trainer (aka address)
    mapping ( address => BattleChallenge ) public s_battlingStatus;

    //get the current details of a battle
    mapping ( uint256 => Battle) public s_battleId;

    //nft counter
    uint256 public s_counter = 0;

    //battle id counter
    uint256 public s_battlingCounter = 0;

    //pokemon nft constructor
    constructor() ERC721("PKMNBattle", "PLMITRIX") {}

    //creates pokemon NFTs
    function createPokemon(uint256[] calldata damages, string[] calldata damageNames, Status calldata status) public {

        s_Pokemons.push(
            Pokemon(
                Attack(damages[0], 200-damages[0],damageNames[0]),
                Attack(damages[1], 200-damages[1],damageNames[1]),
                Attack(damages[2], 200-damages[2],damageNames[2]),
                Attack(damages[3], 200-damages[3],damageNames[3]),
                status
            )
        );

        s_PokemonOwners[msg.sender].push(s_counter);
        _safeMint(msg.sender, s_counter);
        s_counter++;
    }

    //send a challenge request to another trainer by locking your own pokemon
    function battleChallenge(address challengeAddress, uint256 challengerPokemon) public  {

        //makes sure that the two challengers are not in a battle
        require(s_battlingStatus[challengeAddress].status == BattleStatus.Available && s_battlingStatus[msg.sender].status == BattleStatus.Available, "currently in battle" );

        uint256 id = s_battlingCounter;
        s_battleId[id].addr_challenger = msg.sender;
        s_battleId[id].addr_challenged = challengeAddress;
        s_battleId[id].pokemon_challenger = challengerPokemon;

        s_battleId[id].status = BattleStatus.Requested;
        s_battlingStatus[msg.sender].status = BattleStatus.Ongoing;
        s_battlingStatus[challengeAddress].status = BattleStatus.Requested;
        s_battlingCounter++;
    }

    //accept a challenge request
    function setBattleStatus(uint256 pokemonId) public {
        //require a challenge request to be made by another trainer
        require(s_battlingStatus[msg.sender].status == BattleStatus.Requested, "No challenge to accept");
        uint256 id = s_battlingStatus[msg.sender].challengeId;

        //update battle status to ongoing
        s_battlingStatus[msg.sender].status = BattleStatus.Ongoing;
        s_battleId[id].pokemon_challenged = pokemonId;

        //convert to integer to make sure <=0 hp is met
        s_battleId[id].challengerHP = int(s_Pokemons[s_battleId[id].pokemon_challenger].status.hp);
        s_battleId[id].challengedHP = int(s_Pokemons[s_battleId[id].pokemon_challenged].status.hp);
        s_battleId[id].status = BattleStatus.Ongoing;
    }

    // make s_battleId[id] into a localVariable
    function currentBattle(uint256 attackNumber) public {
        uint256 id = s_battlingStatus[msg.sender].challengeId;

        require(s_battleId[id].status == BattleStatus.Ongoing, "No ongoing challenge");

        //store the pokemons and the attacks in local variables
        Pokemon memory challengerPokemon;
        Pokemon memory challengedPokemon;
        Attack memory challengerAttack;
        //VRF INSTEAD OF ONE
        uint256 attackVRF = 1;

        //if turn 1 let one trainer attack
        if(s_battleId[id].turnCounter % 2 == 0){
            challengerPokemon = s_Pokemons[s_battleId[id].pokemon_challenger];
            challengedPokemon = s_Pokemons[s_battleId[id].pokemon_challenged];

            //get the attack's data thats chosen by the trainer
            challengerAttack = getPokemonAttack(attackNumber, challengerPokemon);

            //change the hp of the pokemon being attacked
            s_battleId[id].challengedHP -= int(( challengerAttack.damage * attackVRF ) / 10*(challengedPokemon.status.defenseMod - challengerPokemon.status.attackMod));
        } else {
            challengerPokemon = s_Pokemons[s_battleId[id].pokemon_challenged];
            challengedPokemon = s_Pokemons[s_battleId[id].pokemon_challenger];
            challengerAttack = getPokemonAttack(attackNumber, challengerPokemon);
            s_battleId[id].challengerHP -= int(( challengerAttack.damage * attackVRF ) / 10*(challengedPokemon.status.defenseMod - challengerPokemon.status.attackMod));
        }

        //if a pokemon has fainted then set the battle to completed
        if(s_battleId[id].challengedHP <= 0){
            s_battleId[id].status = BattleStatus.Completed;
            s_battlingStatus[s_battleId[id].addr_challenger].status = BattleStatus.Available;
            s_battlingStatus[s_battleId[id].addr_challenger].status = BattleStatus.Available;
        }

        s_battleId[id].turnCounter++;
    }

    //get pokemon attack details
    function getPokemonAttack(uint256 attackNumber, Pokemon memory pokemon) public pure returns(Attack memory){
        if(attackNumber == 1){
            return(pokemon.move1);
        } else if(attackNumber == 2){
            return(pokemon.move2);
        } else if(attackNumber == 3){
            return(pokemon.move3);
        }
        return(pokemon.move4);
    }
}



// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
// [100,120,150,180]
// ["a","b","c","d"]
// [150, 100, 120, "dumb"]

// 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
// [100,120,150,180]
// ["w","x","y","z"]
// [160, 80, 130, "fuck"]

