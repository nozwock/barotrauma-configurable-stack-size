using System;
using System.Linq;
using System.Reflection;
using System.Text.RegularExpressions;
using Barotrauma;

namespace ConfigurableStackSize
{
    public static class ReflectionExtensions
    {
        public static string FindMethodNameRegex(string className, string pattern)
        {
            Type classType = LuaUserData.GetType(className);
            if (classType == null)
            {
                throw new Exception($"Failed to get a class with name: `{className}`");
            }

            Regex methodRegex = new Regex(pattern);
            return classType
                .GetMethods(
                    BindingFlags.Instance
                    | BindingFlags.Static
                    | BindingFlags.Public
                    | BindingFlags.NonPublic
                )
                .Select(it => methodRegex.Match(it.Name))
                .Where(it => it.Success)
                .Select(it => it.Value)
                .FirstOrDefault();
        }
    }

    internal class ConfigurableStackSizePlugin : IAssemblyPlugin, IDisposable
    {
        public void Initialize()
        {
            // When your plugin is loading, use this instead of the constructor
            // Put any code here that does not rely on other plugins.
        }

        public void OnLoadCompleted()
        {
            // After all plugins have loaded
            // Put code that interacts with other plugins here.
        }

        public void PreInitPatching()
        {
            // Not yet supported: Called during the Barotrauma startup phase before vanilla content is loaded.
        }

        public void Dispose()
        {
            // Cleanup your plugin!
        }
    }
}
