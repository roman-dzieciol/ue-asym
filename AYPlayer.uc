// ============================================================================
//  AYPlayer.uc ::
// ============================================================================
class AYPlayer extends xPlayer
    dependson(AyDataFile);


//var bool invisible,invcool;

// - DataFile -----------------------------------------------------------------

var(DataFile) localized string      MsgInvalidDataFile;

var AyDataFile                      DataFile;               // Client only
var AyDataFile.sDataFilePacked      DataFileCache;          // Server only
var bool                            bDataFileCached;        // Server only
var int                             Experience;


// ============================================================================
//  Replication
// ============================================================================

replication
{
    // Functions server can call.
    reliable if( Role == ROLE_Authority )
        ClientSendDataFile
    ,   ClientReceiveEquipment
    ,   ClientReceiveXP
    ;

    // Functions the client calls on the server.
    reliable if( Role < ROLE_Authority )
        ServerReceiveDataFile
    ,   ServerReceiveEquipment
    ;
}


// ============================================================================
//  DataFile
// ============================================================================

function ClientSendDataFile()
{
    Log( "ClientSendDataFile" );

    // Get DataFile
    if( DataFile == None )
    {
        DataFile = class'AyDataFile'.static.GetDataFile(GetEntryLevel());
        if( DataFile == None )
        {
            RemoveInvalidPlayer(MsgInvalidDataFile);
            return;
        }
    }

    ServerReceiveDataFile(DataFile.GetPacked());
}


function ServerReceiveDataFile( AyDataFile.sDataFilePacked DFP )
{
    Log( "ServerReceiveDataFile" );

    ApplyDataFile(DFP);
}

function bool ApplyDataFile( AyDataFile.sDataFilePacked DFP )
{
    local xUtil.PlayerRecord PR;
    local class<AyPawn> P;

    Log( "Player.ApplyDataFile" @DFP.Character );

    if( bDataFileCached )
    {
        Warn("DataFile already applied!");
        return false;
    }

    // Verify Character
    PR = class'xUtil'.static.FindPlayerRecord(DFP.Character);
    if( DFP.Character != ""
    &&  DFP.Character == PR.DefaultName
    &&  class<AySpecies>(PR.Species) != None )
    {
        P = class<AyPawn>(DynamicLoadObject(PR.Species.default.PawnClassName, class'Class'));
        if( P != None )
        {
            // Cache
            DataFileCache = DFP;
            bDataFileCached = True;

            // Setup Character
            PawnClass = P;
            PawnSetupRecord = PR;
            PlayerReplicationInfo.SetCharacterName(DFP.Character);

            // Open equipment screen
            ClientOpenMenu(P.default.EquipmentMenu);

            return true;
        }
    }

    RemoveInvalidPlayer(MsgInvalidDataFile);
    return false;
}

function RemoveInvalidPlayer( string Reason )
{
    Log( "Removing invalid player:" @self @GetHumanReadableName() );

    ClientNetworkMessage("AC_Kicked",Reason);
    if( NetConnection(Player) != None )
    {
        Destroy();
    }
    else
    {
        if( Player.Console != None )
            Player.Console.DelayedConsoleCommand("Disconnect");
        else ConsoleCommand("Disconnect");
    }
}

final static simulated function AyDataFile GetDataFile( LevelInfo L, optional AyPlayer P )
{
    local AyDataFile DF;

    // Get DataFile from player
    if( P != None )
        DF = P.DataFile;

    // If not found, load from disk
    if( DF == None )
        DF = class'AyDataFile'.static.GetDataFile(L);

    return DF;
}


// ============================================================================
//  Equipment
// ============================================================================

function ChangeEquipment( AyDataFile.sEquipment NewEquipment )
{
    // Notify client & server
    ClientReceiveEquipment(NewEquipment);
    ServerReceiveEquipment(NewEquipment);
}

function ClientReceiveEquipment( AyDataFile.sEquipment NewEquipment )
{
    if( DataFile == None )
    {
        Warn("DataFile missing!");
        return;
    }

    SaveEquipment(NewEquipment);
}

function ServerReceiveEquipment( AyDataFile.sEquipment NewEquipment )
{
    // verify equipment
    // if something was wrong, update client ?

    SetEquipment(NewEquipment);
}

function SaveEquipment( AyDataFile.sEquipment NewEquipment )
{
    if( DataFile == None )
    {
        Warn("SaveEquipment failed, no DataFileObject!");
        return;
    }

    DataFile.Equipment = NewEquipment;
    class'AyDataFile'.static.SavePackage(GetEntryLevel());
}

function LoadEquipment( out AyDataFile.sEquipment NewEquipment )
{
    if( DataFile == None )
    {
        Warn("LoadEquipment failed, no DataFile!");
        return;
    }

    NewEquipment = DataFile.Equipment;
}


function GetEquipment( out AyDataFile.sEquipment NewEquipment )
{
    if( !bDataFileCached )
    {
        Warn("GetEquipment failed, no DataFileCache!");
        return;
    }

    NewEquipment = DataFileCache.Equipment;
}


function SetEquipment( AyDataFile.sEquipment NewEquipment )
{
    if( !bDataFileCached )
    {
        Warn("SetEquipment failed, no DataFileCache!");
        return;
    }

    DataFileCache.Equipment = NewEquipment;
}


// ============================================================================
//  Stats
// ============================================================================

function AddXP( int x )
{
    Experience += x;
    ClientMessage( x @"XP!", 'Event' );
}

function SaveXP()
{
    if( Experience > 0 )
    {
        ClientReceiveXP(Experience);
        Experience = 0;
    }
}

function ClientReceiveXP( int x )
{
    local int LevelsGained;

    if( DataFile == None )
    {
        Warn("ClientReceiveXP failed, no DataFile!");
        return;
    }

    LevelsGained = DataFile.ReceiveXP(x);
    class'AyDataFile'.static.SavePackage(GetEntryLevel());

    ClientMessage( "Received" @x @"experience points!", 'Event' );
    if( LevelsGained > 0 )
        ClientMessage( "Received" @LevelsGained @"character levels!", 'Event' );
}


// ============================================================================
//  Character
// ============================================================================

function SetPawnClass( string inClass, string inCharacter )
{
    // Function intentionally left blank
}

exec function ChangeCharacter(string newCharacter)
{
    // Function intentionally left blank
}


// ============================================================================
//  Pawn
// ============================================================================

function Possess( Pawn P )
{
    local AyPawn AP;

    Super.Possess( P );

    if( !bDataFileCached )
    {
        Warn("Posses() without DataFileCache!");
        return;
    }

    AP = AyPawn(P);
    if( AP != None )
    {
        AP.ApplyDataFile(DataFileCache);
    }
}



// ============================================================================
//  DefaultProperties
// ============================================================================
DefaultProperties
{
    PlayerReplicationInfoClass      = Class'AYTeamGame.AyPRI'
    PawnClass                       = Class'AYTeamGame.AyPawn'
    MsgInvalidDataFile              = "Your character could not be loaded. You have been disconnected."
}
