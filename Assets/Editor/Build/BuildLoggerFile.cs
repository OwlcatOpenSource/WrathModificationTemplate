using System;
using System.IO;
using UnityEditor.Build.Pipeline.Interfaces;
using UnityEditor.Build.Pipeline.Utilities;
using UnityEngine;

namespace OwlcatModification.Editor.Build
{
    public class BuildLoggerFile : IBuildLogger, IDisposable
    {
        private readonly BuildLog m_Builtin = new BuildLog();

        private readonly string m_Filepath;
        private readonly StreamWriter m_Output;
        
        public BuildLoggerFile(string filepath)
        {
            m_Filepath = filepath;
            m_Output = new StreamWriter(filepath);
            
            Application.logMessageReceived += OnLogMessageReceived;
        }

        private void OnLogMessageReceived(string condition, string stacktrace, LogType type)
        {
            m_Output.WriteLine(condition);
            if (type != LogType.Log)
            {
                m_Output.WriteLine(stacktrace);
            }
        }

        public void AddEntry(LogLevel level, string msg)
        {
            m_Builtin.AddEntry(level, msg);

            if (level != LogLevel.Verbose || ScriptableBuildPipeline.useDetailedBuildLog)
            {
                m_Output.WriteLine(msg);
            }
        }

        public void BeginBuildStep(LogLevel level, string stepName, bool subStepsCanBeThreaded)
        {
            m_Builtin.BeginBuildStep(level, stepName, subStepsCanBeThreaded);
        }

        public void EndBuildStep()
        {
            m_Builtin.EndBuildStep();
        }

        public void Dispose()
        {
            Application.logMessageReceived -= OnLogMessageReceived;
            
            m_Output.Dispose();

            using (var traceStream = new StreamWriter(m_Filepath + ".trace"))
            {
                traceStream.WriteLine(m_Builtin.FormatForTraceEventProfiler());
            }
        }
    }
}