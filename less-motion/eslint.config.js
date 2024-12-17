module.exports = {
        root: true,
        env: {
                node: true,
        },
        extends: [
                'eslint:recommended',
                'plugin:prettier/recommended',
        ],
        parserOptions: {
                ecmaVersion: 2020,
        },
        rules: {
                'prettier/prettier': [
                        'error',
                        {
                                printWidth: 100,
                                tabWidth: 8,
                                useTabs: false,
                                singleQuote: true,
                                jsxSingleQuote: true,
                                trailingComma: 'none',
                                bracketSameLine: false,
                                singleAttributePerLine: true,
                                spaceBeforeFunctionParen: true,
                        },
                ],
        },
};
