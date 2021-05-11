using System;
using JetBrains.Annotations;
using Kingmaker.Modding;
using UnityEngine;

namespace OwlcatModification.Editor
{
    [CreateAssetMenu(menuName = "Modification")]
    public class Modification : ScriptableObject
    {
        [Serializable]
        public class SettingsData
        {
        }

        public OwlcatModificationManifest Manifest = new OwlcatModificationManifest();
        public SettingsData Settings = new SettingsData();
    }
}
