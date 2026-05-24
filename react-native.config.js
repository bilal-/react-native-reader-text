module.exports = {
  dependency: {
    platforms: {
      android: {
        packageImportPath: 'import com.readertext.ReaderTextPackage;',
        packageInstance: 'new ReaderTextPackage()',
      },
      ios: {},
    },
  },
};
