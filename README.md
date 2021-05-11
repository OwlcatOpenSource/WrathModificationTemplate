Getting started
===============

1. Open the project using **Unity 2019.4.0f1**
    * Unity console will show many compiler errors, but **don't panic**!
    * Click **Modification Tools -> Setup project** menu entry and choose _**Pathfinder: Wrath of the Righteous** installation folder_ in the dialog that will appear
    * If Unity shows you **API Update Required** dialog click **No Thanks**
    * Close and reopen project
    * Click **Modification Tools -> Setup render pipeline** menu entry
    * Project is now ready

2. Setup your modification (take a look at _Assets/Modifications/ExampleModification_ for examples)
    * Create a folder for your modification in **Assets/Modifications**
    * Create **Modification** scriptable object in this folder _(right click on folder -> Create -> Modification)_
        * Specify **Unique Name** in **Modification** scriptable object
    * Create **Scripts** folder and **_your-modification-name_.Scripts.asmdef** file inside it _(right click on folder -> Create -> Assembly Definition)_
    * Create **Content**, **Blueprints** and **Localization** folders as needed

3. Create your modification

4. Build your modification (use **Modification Tools -> Build** menu entry)

5. Test your modification
    * Copy **Build/your-modification-name** folder to **_user-folder_/AppData/LocalLow/Owlcat Games/Pathfinder Wrath Of The Righteous/Modifications**
    * Add your modification to **_user-folder_/AppData/LocalLow/Owlcat Games/Pathfinder Wrath Of The Righteous/OwlcatModificationManangerSettings.json**
        ```json5
        {
            "EnabledModifications": ["your-modification-name"] // use name from the manifest(!), not folder name
        }
        ```
    * Run Pathfinder: Wrath of the Righteous

5. Publish build results from **Build** folder
    * _TODO_

Features
========

All content of your modification must be placed in folder with **Modification** scriptable object or it's subfolders.

### Scripts

All of your scripts must be placed in assemblies (in folder with ***.asmdef** files or it's subfolders). **Never** put your scripts (except Editor scripts) in other places.

### Content

All of your content (assets, prefabs, scenes, sprites, etc) must be placed in **_your-modification-name_/Content** folder.

### Blueprints

Blueprints are JSON files which represent serialized version of static game data (classes inherited from **SimpleBlueprint**).

* Blueprints must have file extension ***.jbp** and must be situated in **_your-modification-name_/Blueprints** folder.
    * _example: Examples/Basics/Blueprints/TestBuff.jbp_

    ```json5
    // *.jbp file format
    {
        "AssetId": "unity-file-guid-from-meta", // "42ea8fe3618449a5b09561d8207c50ab" for example
        "Data": {
            "$type": "type-id, type-name", // "618a7e0d54149064ab3ffa5d9057362c, BlueprintBuff" for example
            
            // type-specific data
        }
    }
    ```

    * if you specify **AssetId** of an existing blueprint (built-in or from another modification) then the existing blueprint will be replaced

* For access to metadata of all built-in blueprints use this method
    ```C#
    // read data from <WotR-installation-path>/Bundles/cheatdata.json
    // returns object {Entries: [{Name, Guid, TypeFullName}]}
    BlueprintList Kingmaker.Cheats.Utilities.GetAllBlueprints();
    ```

* You can write patches for existing blueprints: to do so, create a ***.patch** JSON file in **_your-modification-name_/Blueprints** folder. Instead of creating a new blueprint, these files will modify existing ones by changing only fields that are specified in the patch and retaining everything else as-is.

    * _Example: Examples/Basics/Blueprints/ChargeAbility.patch_

    * Connection between the existing blueprint and the patch must be specified in **BlueprintPatches** scriptable object _(right click in folder -> Create -> Blueprints' Patches)_

        * _example: Examples/Basics/BlueprintPatches.asset_

    ```json5
    // *.patch file format: change icon in BlueprintBuff
    {
        "m_Icon": {"guid": "c0fe3dda356ba6349bd5a8d39aad7ecb", "fileid": 21300000}
    }
    ```

### Localization

You can add localized strings to the game or replace existing strings. Create **enGB|ruRU|deDE|frFR|zhCN|esES.json** file(s) in **_your-modification-name_/Localization** folder.

* _example: Examples/Basics/Localizations/enGB.json_

* You shouldn't copy enGB locale with different names if creating only enGB strings: enGB locale will be used if modification doesn't contains required locale.

* The files should be in UTF-8 format (no fancy regional encodings, please!)

```json5
// localization file fromat
{
    "strings": [
        {
            "Key": "guid", // "15edb451-dc5b-4def-807c-a451743eb3a6" for example
            "Value": "whatever-you-want"
        }
    ]
}
```

### Assembly entry point

You can mark static method with **OwlcatModificationEnterPoint** attribute and the game will invoke this method with corresponding _OwlcatModification_ parameter once on game start. Only one entry point per assembly is allowed.

* _example: Examples/Basics/Scripts/ModificationRoot.cs (ModificationRoot.Initialize method)_

```C#
[OwlcatModificationEnterPoint]
public static void EnterPoint(OwlcatModification modification)
{
    ...
}
```

### Storing data

* You can save/load global modification's data or settings with methods _OwlcatModification_.**LoadData** and  _OwlcatModification_.**SaveData**. Unity Serializer will be used for saving this data.

    * _Example: Examples/Basics/Scripts/ModificationRoot.cs (ModificationRoot.TestData method)_

    ```C#
    [Serialzable]
    public class ModificationData
    {
        public int IntValue;
    }
    ...
    OwlcatModification modification = ...;
    var data = modification.LoadData<ModificationData>();
    data.IntValue = 42;
    modification.SaveData(data);
    ```

* You can save/load per-save modification's data or settings by adding custom **EntityPart** to **Game.Instance.Player**. **JsonProperty** attribute required for serializing field or property in save.

    ```C#
    public class ModificationPlayerData : EntityPart
    {
        [JsonProperty]
        public int IntValue;
    }
    ...
    var data = Game.Instance.Player.Ensure<ModificationPlayerData>();
    data.IntValue = 42;
    ```

### EventBus

You can subscribe to game events with **EventBus.Subscribe** or raise your own event using **EventBus.RaiseEvent**.

* _Example (subscribe): Examples/Basics/Scripts/ModificationRoot.cs (ModificationRoot.Initialize method)_

* Raise your own event:

    ```C#
    interface IModificationEvent : IGlobalSubscriber
    {
        void HandleModificationEvent(int intValue);
    }
    ...
    EventBus.RaiseEvent<IModificationEvent>(h => h.HandleModificationEvent(42))
    ```

### Rulebook Events

* **IBeforeRulebookEventTriggerHandler** and **IAfterRulebookEventTriggerHandler** exists specifically for modifications. These events are raised before _OnEventAboutToTrigger_ and _OnEventDidTigger_ correspondingly.
* Use _RulebookEvent_.**SetCustomData** and _RulebookEvent_.**TryGetCustomData** to store and read your custom RulebookEvent data.

### Resources

_OwlcatModification_.**LoadResourceCallbacks** is invoked every time when a resource (asset, prefab or blueprint) is loaded.

### Game Modes and Controllers

A **Controller** is a class that implements a particular set of game mechanics. It must implementi _IController_ interface.

**Game Modes** (objects of class _GameMode_) are logical groupings of **Controllers** which all must be active at the same time. Only one **Game Mode** can be active at any moment. Each frame the game calls **Tick** method for every **Controller** in active **Game Mode**. You can add your own logic to Pathfinder's main loop or extend/replace existing logic using **OwlcatModificationGameModeHelper**.

* _Example (subscribe): Examples/Basics/Scripts/Tests/ControllersTest.cs_

### Using Pathfinder shaders

Default Unity shaders doesn't work in Pathfinder. Use shaders from **Owlcat** namespace in your materials. If you don't know what you need it's probably **Owlcat/Lit** shader.

### Scenes

You can create scenes for modifications but there is a couple limitations:

* if you want to use Owlcat's MonoBehaviours (i.e. UnitSpawner) you must inherit from it and use child class defined in your assembly

* place an object with component **OwlcatModificationMaterialsInSceneFixer** in every scene which contains Renderers

### Helpers

* Copy guid and file id as json string: _right-click-on-asset -> Modification Tools -> Copy guid and file id_

* Copy blueprint's guid: _right-click-on-blueprint -> Modification Tools -> Copy blueprint's guid_
    
* Create blueprint: _right-click-in-folder -> Modification Tools -> Create Blueprint_

* Find blueprint's type: _Modification Tools -> Blueprints' Types_

### Interactions and dependencies between modifications

Work in progress. Please note that users will be able to change order of mods in the manager. We're planning to provide the ability to specify a list of dependencies for your modification, but it will only work as a hint: the user will be responsible for arranging a correct order of mods in the end.
 
### Testing

* Command line argument **-start_from=_area-name/area-preset-name_** allows you to start game from the specified area without loading main menu.
* Cheat **reload_modifications_data** allows you to reload content, blueprints and localizations. All instantiated objects (prefab instances, for example) stays unchanged.