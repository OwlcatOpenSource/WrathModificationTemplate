using Kingmaker.Controllers.Units;
using Kingmaker.GameModes;
using Kingmaker.Modding;

namespace OwlcatModification.Modifications.Examples.Basics.Tests
{
	public static class ControllersTest
	{
		private static readonly GameModeType NewGameMode = new GameModeType("NewGameMode");
		
		public static void SetupControllers()
		{
			OwlcatModificationGameModeHelper
				.GetControllerInserterBefore<UnitMoveController>()
				.Insert(new Controller1(), GameModeType.Default, GameModeType.Pause)
				.Insert(new Controller2(), GameModeType.Default, GameModeType.Pause);
			
			OwlcatModificationGameModeHelper
				.OverrideController<UnitMoveController>(new Controller3(), true);

			OwlcatModificationGameModeHelper
				.GetControllerInserterAfter<UnitMoveController>()
				.Insert(new Controller4(), NewGameMode)
				.Insert(new Controller5(), GameModeType.Default, GameModeType.Pause)
				.Insert(new Controller6(), GameModeType.Default, GameModeType.Pause);
		}

		private class Controller1 : OwlcatModificationController
		{
		}

		private class Controller2 : OwlcatModificationController
		{
		}

		private class Controller3 : OwlcatModificationController
		{
		}

		private class Controller4 : OwlcatModificationController
		{
		}

		private class Controller5 : OwlcatModificationController
		{
		}

		private class Controller6 : OwlcatModificationController
		{
		}
	}
}