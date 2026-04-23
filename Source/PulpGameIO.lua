import "PulpGameIOShared"
import "PulpGameIOSave"
import "PulpGameIOLoad"

PulpGameIO = {
    remapTileMappings = PulpGameIOLoad.remapTileMappings,
    buildSaveDocument = PulpGameIOSave.buildSaveDocument,
    prepareLoadedGame = PulpGameIOLoad.prepareLoadedGame
}

return PulpGameIO