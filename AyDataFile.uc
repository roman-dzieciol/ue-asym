// ============================================================================
//  AyDataFile.uc ::
// ============================================================================
class AyDataFile extends AyObject;



// - Structs ------------------------------------------------------------------

struct sEquipment
{
    var() class<Weapon> Weapons[8];
};

struct sSkills
{
    var() int Tree[5];
};

struct sDataFilePacked
{
    var() string Character;
    var() int XP;
    var() sSkills Skills;
    var() sEquipment Equipment;
    var() byte Strength;
    var() byte Dexterity;
    var() byte Constitution;
    var() byte Reflex;
    var() int CharLevel;
};


// - FileSystem ---------------------------------------------------------------

var const class<AyDataFile>     DataFileClass;
var const string                DataFilePackage;


// - Localized ----------------------------------------------------------------

var const localized string DefDataName;
var const localized string MsgNoLevel;
var const localized string MsgNoDataFile;
var const localized string MsgNoDataInfo;
var const localized string MsgNoDataFileDelete;
var const localized string MsgNoDataFileCreate;

// - Stats --------------------------------------------------------------------

var const array<int> LevelXP;
var const array<int> LevelSkills;
var const array<int> LevelStats;

var const int CharLevelMax;


// - Serialized ---------------------------------------------------------------

var() int Version;
var() string DataName;
var() string Character;
var() int XP;
var() sSkills Skills;
var() sEquipment Equipment;

var() int Strength;
var() int Dexterity;
var() int Constitution;
var() int Reflex;

var() int SkillPoints;
var() int StatPoints;

var() int CharLevel;


// ============================================================================
//  Stats
// ============================================================================

final simulated function int ReceiveXP( int x )
{
    local int i, LevelsGained;

    // Add XP
    x = Max(x,0);
    XP += x;

    // Award points
    if( CharLevel < CharLevelMax )
    {
        for( i=CharLevel+1; i<CharLevelMax; ++i )
        {
            if( XP >= LevelXP[i] )
            {
                SkillPoints += LevelSkills[i];
                StatPoints += LevelStats[i];
                CharLevel = i;
                ++LevelsGained;
                continue;
            }
            else
            {
                break;
            }
        }
    }

    return LevelsGained;
}



// ============================================================================
//  DataFile
// ============================================================================

final simulated function Initialize
(
    optional string InDataName
,   optional string InCharacter
)
{
    local xUtil.PlayerRecord PR;
    local class<AyPawn> P;

    if( InDataName != "" )
        DataName = InDataName;
    else
        DataName = DefDataName;

    if( InCharacter != "" )
        Character = InCharacter;

    PR = class'xUtil'.static.FindPlayerRecord(Character);
    P = class<AyPawn>(DynamicLoadObject(PR.Species.default.PawnClassName, class'Class'));

    Strength = P.default.StrengthLevel;
    Dexterity = P.default.DexterityLevel;
    Constitution = P.default.ConstitutionLevel;
    Reflex = P.default.ReflexLevel;

    SkillPoints = default.LevelSkills[0];
    StatPoints = default.LevelStats[0];
}

final simulated function sDataFilePacked GetPacked()
{
    local sDataFilePacked DFP;

    DFP.Character = Character;
    DFP.XP = XP;
    DFP.Skills = Skills;
    DFP.Equipment = Equipment;

    DFP.Strength = Strength;
    DFP.Dexterity = Dexterity;
    DFP.Constitution = Constitution;
    DFP.Reflex = Reflex;

    DFP.CharLevel = CharLevel;

    return DFP;
}



// ============================================================================
//  DataFile Manager
// ============================================================================

final static simulated function bool SetSelected( LevelInfo L, AyDataFile DF )
{
    local AyDataInfo DI;

    nLog( "SetSelected" );

    // Check Level
    if( L == None )
    {
        Warn(default.MsgNoLevel);
        return false;
    }

    // Get DataInfo
    DI = GetDataInfo(L);
    if( DI == None )
    {
        Warn(default.MsgNoDataInfo);
        return false;
    }

    // Set Selected DataFile
    DI.Selected = DF;
    SavePackage(L);
    return true;
}


final static simulated function AyDataFile GetDataFile( LevelInfo L )
{
    local AyDataInfo DI;
    local AyDataFile DF;

    nLog( "GetDataFile" );

    // Check Level
    if( L == None )
    {
        Warn(default.MsgNoLevel);
        return None;
    }

    // Get DataInfo
    DI = GetDataInfo(L);
    if( DI == None )
    {
        Warn(default.MsgNoDataInfo);
        return None;
    }

    // Get selected DataFile
    DF = AyDataFile(DI.Selected);

    // If selection invalid
    if( DF == None )
    {
        // Get first existing
        DF = GetFirstDataFile(L);

        // If none exist
        if( DF == None )
        {
            // Create new
            DF = CreateDataFile(L);
            if( DF != None )
            {
                DF.Initialize();
            }
        }

        // Update selection
        if( DF != None )
        {
            DI.Selected = DF;
            SavePackage(L);
        }
        else
        {
            Warn(default.MsgNoDataFile);
            return None;
        }
    }

    return DF;
}


final static simulated function AyDataFile CreateCharacter( LevelInfo L, string DataName, string NewCharacter )
{

    local AyDataInfo DI;
    local AyDataFile DF;

    nLog( "GetDataFile" );

    // Check Level
    if( L == None )
    {
        Warn(default.MsgNoLevel);
        return None;
    }

    // Get DataInfo
    DI = GetDataInfo(L);
    if( DI == None )
    {
        Warn(default.MsgNoDataInfo);
        return None;
    }

    // Create new DataFile
    DF = CreateDataFile(L);
    if( DF != None )
    {
        DI.Selected = DF;
        DF.Initialize(DataName,NewCharacter);
        SavePackage(L);
    }
    else
    {
        Warn(default.MsgNoDataFileCreate);
        return None;
    }

    return DF;
}



final static simulated function bool SafeDeleteDataFile( LevelInfo L, AyDataFile DF )
{
    local AyDataInfo DI;

    nLog( "SafeDeleteDataFile" );

    // Check Level
    if( L == None )
    {
        Warn(default.MsgNoLevel);
        return false;
    }

    // Check DataFile
    if( DF == None )
    {
        Warn(default.MsgNoDataFile);
        return false;
    }

    // Get DataInfo
    DI = GetDataInfo(L);
    if( DI == None )
    {
        Warn(default.MsgNoDataInfo);
        return false;
    }

    // Update selection
    if( DI.Selected == DF )
    {
        DI.Selected = GetFirstDataFile(L,DF);
        SavePackage(L);
    }

    // Delete
    if( DeleteDataFile(L,DF) )
    {
        SavePackage(L);
    }
    else
    {
        Warn(default.MsgNoDataFileDelete);
        return false;
    }

    return true;
}

final static simulated function SavePackage( LevelInfo L )
{
    L.Game.SavePackage(default.DataFilePackage);
}


// ============================================================================
//  AyDataInfo - raw commands
// ============================================================================

final static simulated function AyDataInfo GetDataInfo( LevelInfo L )
{
    local AyDataInfo DI;

    DI = LoadDataInfo(L);
    if( DI != None )
        return DI;

    return CreateDataInfo(L);
}

final static simulated function AyDataInfo LoadDataInfo( LevelInfo L )
{
    return L.Game.LoadDataObject(class'AyDataInfo', "AyDataInfo", default.DataFilePackage);
}

final static simulated function AyDataInfo CreateDataInfo( LevelInfo L )
{
    nLog("Creating new DataInfo:" @default.DataFilePackage$".AyDataInfo");
    return L.Game.CreateDataObject(class'AyDataInfo', "AyDataInfo", default.DataFilePackage);
}


// ============================================================================
//  AyDataFile - raw commands
// ============================================================================

final static simulated function GetDataFiles( LevelInfo L, out array<AyDataFile> A )
{
    local AyDataFile DF;

    A.Length = 0;
    foreach L.Game.AllDataObjects(class'AyDataFile', DF, default.DataFilePackage)
    {
        if( DF != None )
        {
            A[A.Length] = DF;
        }
    }
}

final static simulated function AyDataFile GetFirstDataFile( LevelInfo L, optional AyDataFile Avoid )
{
    local AyDataFile DF;

    foreach L.Game.AllDataObjects(class'AyDataFile', DF, default.DataFilePackage)
        if( DF != Avoid && DF != None )
            return DF;

    return None;
}

final static simulated function AyDataFile CreateDataFile( LevelInfo L )
{
    local string ObjectName;

    ObjectName = CreateObjectName(L);
    nLog("Creating new DataFile:" @default.DataFilePackage$"."$ObjectName);
    return L.Game.CreateDataObject(default.DataFileClass, ObjectName, default.DataFilePackage);
}

final static simulated function bool DeleteDataFile( LevelInfo L, AyDataFile DF )
{
    nLog("Deleting DataFile:" @DF);
    return L.Game.DeleteDataObject(default.DataFileClass, string(DF.Name), default.DataFilePackage);
}




// ============================================================================
//  Equipment
// ============================================================================

final static simulated function WrapWeaponsArray( out sEquipment W, class<Weapon> A[8] )
{
    local int i;
    for( i=0; i!=ArrayCount(A); ++i )
        W.Weapons[i] = A[i];
}

final static simulated function UnwrapWeaponsArray( sEquipment W, out class<Weapon> A[8] )
{
    local int i;
    for( i=0; i!=ArrayCount(A); ++i )
        A[i] = W.Weapons[i];
}

// ============================================================================
//  Skills
// ============================================================================
final static simulated function sSkills WrapSkillsArray( int A[5] )
{
    local sSkills W;
    local int i;

    for( i=0; i!=ArrayCount(A); ++i )
        W.Tree[i] = A[i];

    return W;
}


final static simulated function string CreateObjectName( LevelInfo Level )
{
    local string S;

    S = "Ay";
    S $= "_" $Level.Year;
    S $= "_" $Level.Month;
    S $= "_" $Level.Day;
    S $= "_" $Level.Hour;
    S $= "_" $Level.Minute;
    S $= "_" $Level.Second;
    S $= "_" $Level.Millisecond;

    return S;
}

final static simulated function PackSkills
(
    int s0[21]
,   int s1[13]
,   int s2[13]
,   int s3[13]
,   int s4[13]
,   out int Packed[5]
)
{
    local int i;
    local string s[5];

    for(i=0; i!=5; ++i)
    {
        Packed[i] = 0;
    }

    for(i=0; i!=21; ++i)
    {
        if( s0[i] != 0 ) Packed[0] += 1 << i; s[0] @= s0[i];
    }

    for(i=0; i!=13; ++i)
    {
        if( s1[i] != 0 ) Packed[1] += 1 << i;   s[1] @= s1[i];
        if( s2[i] != 0 ) Packed[2] += 1 << i;   s[2] @= s2[i];
        if( s3[i] != 0 ) Packed[3] += 1 << i;   s[3] @= s3[i];
        if( s4[i] != 0 ) Packed[4] += 1 << i;   s[4] @= s4[i];
    }

    log("PackSkills 0:" @s[0]);
    log("PackSkills 1:" @s[1]);
    log("PackSkills 2:" @s[2]);
    log("PackSkills 3:" @s[3]);
    log("PackSkills 4:" @s[4]);
}


final static simulated function UnpackSkills
(
    int Packed[5]
,   out int s0[21]
,   out int s1[13]
,   out int s2[13]
,   out int s3[13]
,   out int s4[13]
)
{
    local int i;
    local string s[5];

    for( i=0; i!=21; ++i )
    {
        s0[i] = int((Packed[0] & (1 << i)) != 0); s[0] @= s0[i];
    }

    for(i=0; i!=13; ++i)
    {
        s1[i] = int((Packed[1] & (1 << i)) != 0);   s[1] @= s1[i];
        s2[i] = int((Packed[2] & (1 << i)) != 0);   s[2] @= s2[i];
        s3[i] = int((Packed[3] & (1 << i)) != 0);   s[3] @= s3[i];
        s4[i] = int((Packed[4] & (1 << i)) != 0);   s[4] @= s4[i];
    }

    log("UnpackSkills 0:" @s[0]);
    log("UnpackSkills 1:" @s[1]);
    log("UnpackSkills 2:" @s[2]);
    log("UnpackSkills 3:" @s[3]);
    log("UnpackSkills 4:" @s[4]);
}


// ============================================================================
//  Debug
// ============================================================================

final static simulated function nLog( coerce string S )
{
    Log(S,'DataFile');
}


// ============================================================================
//  DefaultProperties
// ============================================================================
DefaultProperties
{
    Version             = 1
    Character           = "HumanMaleA"
    DataFileClass       = class'AyDataFile'
    DataFilePackage     = "AyDataFile";

    DefDataName         = "Default"
    MsgNoLevel          = "LevelInfo not found!"
    MsgNoDataFile       = "DataFile not found!"
    MsgNoDataInfo       = "DataInfo not found!"
    MsgNoDataFileDelete = "DataFile could not be deleted!"
    MsgNoDataFileCreate = "DataFile could not be created!"

    CharLevelMax = 65

    LevelXP[0]  = 0
    LevelXP[1]  = 100
    LevelXP[2]  = 250
    LevelXP[3]  = 450
    LevelXP[4]  = 700
    LevelXP[5]  = 1000
    LevelXP[6]  = 1350
    LevelXP[7]  = 1750
    LevelXP[8]  = 2200
    LevelXP[9]  = 2700
    LevelXP[10] = 3250
    LevelXP[11] = 3850
    LevelXP[12] = 4500
    LevelXP[13] = 5200
    LevelXP[14] = 5950
    LevelXP[15] = 6750
    LevelXP[16] = 7600
    LevelXP[17] = 8500
    LevelXP[18] = 9450
    LevelXP[19] = 10450
    LevelXP[20] = 11500
    LevelXP[21] = 12600
    LevelXP[22] = 13750
    LevelXP[23] = 14950
    LevelXP[24] = 16200
    LevelXP[25] = 17500
    LevelXP[26] = 18850
    LevelXP[27] = 20250
    LevelXP[28] = 21700
    LevelXP[29] = 23200
    LevelXP[30] = 24750
    LevelXP[31] = 26350
    LevelXP[32] = 28000
    LevelXP[33] = 29700
    LevelXP[34] = 31450
    LevelXP[35] = 33250
    LevelXP[36] = 35100
    LevelXP[37] = 37000
    LevelXP[38] = 38950
    LevelXP[39] = 40950
    LevelXP[40] = 43000
    LevelXP[41] = 45100
    LevelXP[42] = 47250
    LevelXP[43] = 49450
    LevelXP[44] = 51700
    LevelXP[45] = 54000
    LevelXP[46] = 56350
    LevelXP[47] = 58750
    LevelXP[48] = 61200
    LevelXP[49] = 63700
    LevelXP[50] = 66250
    LevelXP[51] = 68850
    LevelXP[52] = 71500
    LevelXP[53] = 74200
    LevelXP[54] = 76950
    LevelXP[55] = 79750
    LevelXP[56] = 82600
    LevelXP[57] = 85500
    LevelXP[58] = 88450
    LevelXP[59] = 91450
    LevelXP[60] = 94500
    LevelXP[61] = 97600
    LevelXP[62] = 100750
    LevelXP[63] = 103950
    LevelXP[64] = 107200

    LevelSkills[0]  = 1
    LevelSkills[1]  = 1
    LevelSkills[2]  = 0
    LevelSkills[3]  = 0
    LevelSkills[4]  = 1
    LevelSkills[5]  = 0
    LevelSkills[6]  = 0
    LevelSkills[7]  = 1
    LevelSkills[8]  = 0
    LevelSkills[9]  = 0
    LevelSkills[10] = 1
    LevelSkills[11] = 0
    LevelSkills[12] = 0
    LevelSkills[13] = 1
    LevelSkills[14] = 0
    LevelSkills[15] = 0
    LevelSkills[16] = 1
    LevelSkills[17] = 0
    LevelSkills[18] = 0
    LevelSkills[19] = 1
    LevelSkills[20] = 0
    LevelSkills[21] = 0
    LevelSkills[22] = 1
    LevelSkills[23] = 0
    LevelSkills[24] = 0
    LevelSkills[25] = 1
    LevelSkills[26] = 0
    LevelSkills[27] = 0
    LevelSkills[28] = 1
    LevelSkills[29] = 0
    LevelSkills[30] = 0
    LevelSkills[31] = 1
    LevelSkills[32] = 0
    LevelSkills[33] = 0
    LevelSkills[34] = 1
    LevelSkills[35] = 0
    LevelSkills[36] = 0
    LevelSkills[37] = 1
    LevelSkills[38] = 0
    LevelSkills[39] = 0
    LevelSkills[40] = 1
    LevelSkills[41] = 0
    LevelSkills[42] = 0
    LevelSkills[43] = 1
    LevelSkills[44] = 0
    LevelSkills[45] = 0
    LevelSkills[46] = 1
    LevelSkills[47] = 0
    LevelSkills[48] = 0
    LevelSkills[49] = 1
    LevelSkills[50] = 0
    LevelSkills[51] = 0
    LevelSkills[52] = 1
    LevelSkills[53] = 0
    LevelSkills[54] = 0
    LevelSkills[55] = 1
    LevelSkills[56] = 0
    LevelSkills[57] = 0
    LevelSkills[58] = 1
    LevelSkills[59] = 0
    LevelSkills[60] = 0
    LevelSkills[61] = 1
    LevelSkills[62] = 0
    LevelSkills[63] = 0
    LevelSkills[64] = 1

    LevelStats[0]  = 5
    LevelStats[1]  = 5
    LevelStats[2]  = 5
    LevelStats[3]  = 5
    LevelStats[4]  = 5
    LevelStats[5]  = 5
    LevelStats[6]  = 5
    LevelStats[7]  = 5
    LevelStats[8]  = 5
    LevelStats[9]  = 5
    LevelStats[10] = 5
    LevelStats[11] = 5
    LevelStats[12] = 5
    LevelStats[13] = 5
    LevelStats[14] = 5
    LevelStats[15] = 5
    LevelStats[16] = 5
    LevelStats[17] = 5
    LevelStats[18] = 5
    LevelStats[19] = 5
    LevelStats[20] = 5
    LevelStats[21] = 5
    LevelStats[22] = 5
    LevelStats[23] = 5
    LevelStats[24] = 5
    LevelStats[25] = 5
    LevelStats[26] = 5
    LevelStats[27] = 5
    LevelStats[28] = 5
    LevelStats[29] = 5
    LevelStats[30] = 5
    LevelStats[31] = 5
    LevelStats[32] = 5
    LevelStats[33] = 5
    LevelStats[34] = 5
    LevelStats[35] = 5
    LevelStats[36] = 5
    LevelStats[37] = 5
    LevelStats[38] = 5
    LevelStats[39] = 5
    LevelStats[40] = 5
    LevelStats[41] = 5
    LevelStats[42] = 5
    LevelStats[43] = 5
    LevelStats[44] = 5
    LevelStats[45] = 5
    LevelStats[46] = 5
    LevelStats[47] = 5
    LevelStats[48] = 5
    LevelStats[49] = 5
    LevelStats[50] = 5
    LevelStats[51] = 5
    LevelStats[52] = 5
    LevelStats[53] = 5
    LevelStats[54] = 5
    LevelStats[55] = 5
    LevelStats[56] = 5
    LevelStats[57] = 5
    LevelStats[58] = 5
    LevelStats[59] = 5
    LevelStats[60] = 5
    LevelStats[61] = 5
    LevelStats[62] = 5
    LevelStats[63] = 5
    LevelStats[64] = 5
}
