module.exports = {
  dependency: {
    platforms: {
      android: {
        packageImportPath:
          'import dev.bilalahmad.readertext.ReaderTextPackage;',
        packageInstance: 'new ReaderTextPackage()',
      },
      ios: {},
    },
  },
};
