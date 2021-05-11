using System.Collections.Generic;
using UnityEditor.Build;
using UnityEditor.Rendering;
using UnityEngine;

namespace OwlcatModification.Editor.Build
{
	public class ShaderPreprocessor : IPreprocessShaders
	{
		public int callbackOrder
			=> 0;

		public void OnProcessShader(Shader shader, ShaderSnippetData snippet, IList<ShaderCompilerData> data)
		{
			data.Clear();
		}
	}
}