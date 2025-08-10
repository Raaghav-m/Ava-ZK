#!/usr/bin/env node

const fs = require('fs-extra');
const path = require('path');
const prompts = require('prompts');
const kleur = require('kleur');

// __dirname is available in CommonJS

// Circuit templates
const circuits = {
    'age-verification': {
        name: 'Age Verification Circuit',
        description: 'Proves age is above 18 using date of birth without revealing exact age',
        file: 'age.circom',
        content: `pragma circom 2.0.0;

include "circomlib/circuits/comparators.circom";

template Over18Check(){
    signal input dob;            // e.g., days since epoch
    signal input currentdate;    // e.g., days since epoch
    signal output isOver18;      // final output: 1 if over 18

    signal mindob;
    mindob <== currentdate - 6570; // 18 years * 365 days

    component check = LessThan(32);
    check.in[0] <== dob;
    check.in[1] <== mindob;

    isOver18 <== check.out;  // 1 if dob < mindob
}

component main = Over18Check();`,
        input: { "dob": 13069, "currentdate": 20310 }
    },

    'credit-check': {
        name: 'Credit Score Circuit',
        description: 'Proves credit score meets minimum requirements',
        file: 'credit.circom',
        content: `pragma circom 2.0.0;

// Import Num2Bits from circomlib (make sure circomlib is installed)
include "circomlib/circuits/bitify.circom";

template MinCheck(minValue) {
    signal input in;
    signal output valid;

    signal diff;
    diff <== in - minValue;

    // Enforce diff >= 0 by bit decomposition
    component bitsDecomp = Num2Bits(32);
    bitsDecomp.in <== diff;

    valid <== 1;  // Just output 1 if constraints hold
}

template CreditAndBalanceCheck(minBalance, minCredit) {
    signal input balance;
    signal input creditScore;
    signal output isValid;

    component balCheck = MinCheck(minBalance);
    component creditCheck = MinCheck(minCredit);

    balCheck.in <== balance;
    creditCheck.in <== creditScore;

    // Both must be valid
    isValid <== balCheck.valid * creditCheck.valid;
}

component main = CreditAndBalanceCheck(100, 650);`,
        input: { "balance": 150, "creditScore": 700 }
    },

    'min-balance': {
        name: 'Minimum Balance Proof Circuit',
        description: 'Proves account balance meets minimum requirement without revealing exact amount',
        file: 'min.circom',
        content: `pragma circom 2.0.0;
include "circomlib/circuits/bitify.circom";


template MinBalance(minBalance) {
    signal input balance;     // secret input (private)
    signal output isValid;    // output 1 if balance >= minBalance else 0


    signal diff;
    diff <== balance - minBalance;
    component bitsDecomp = Num2Bits(32);
    bitsDecomp.in <== diff;
    isValid <== 1;
}

component main = MinBalance(100);`,
        input: { "balance": 150 }
    }
};

async function main() {
    console.log(kleur.cyan().bold('🔬 Create ZK Proof Project'));
    console.log();

    const result = await prompts([
        {
            type: 'text',
            name: 'projectName',
            message: 'Project name:',
            initial: 'my-zk-project',
            validate: (value) => value.length > 0 ? true : 'Project name is required'
        },
        {
            type: 'select',
            name: 'circuit',
            message: 'Choose a circuit template:',
            choices: Object.entries(circuits).map(([key, circuit]) => ({
                title: circuit.name,
                description: circuit.description,
                value: key
            }))
        },
        {
            type: 'confirm',
            name: 'installDeps',
            message: 'Install dependencies?',
            initial: true
        }
    ]);

    if (!result.projectName || !result.circuit) {
        console.log(kleur.red('❌ Setup cancelled'));
        process.exit(1);
    }

    const projectPath = path.resolve(result.projectName);
    const selectedCircuit = circuits[result.circuit];

    try {
        // Create project directory
        await fs.ensureDir(projectPath);
        console.log(kleur.green(`📁 Creating project in ${projectPath}`));

        // Copy base template files from the zk-proof directory
        const templatePath = path.join(__dirname, '../templates/base');
        await copyBaseTemplate(templatePath, projectPath);

        // Create circuit file
        await fs.writeFile(
            path.join(projectPath, selectedCircuit.file),
            selectedCircuit.content
        );

        // Create input.json
        await fs.writeFile(
            path.join(projectPath, 'input.json'),
            JSON.stringify(selectedCircuit.input, null, 2)
        );

        // Update package.json with project name
        const packageJsonPath = path.join(projectPath, 'package.json');
        const packageJson = await fs.readJson(packageJsonPath);
        packageJson.name = result.projectName;

        // Update circuit reference in scripts
        const circuitName = selectedCircuit.file.replace('.circom', '');
        packageJson.scripts.compile = `bash ./circom_workflow.sh ${selectedCircuit.file}`;

        await fs.writeJson(packageJsonPath, packageJson, { spaces: 2 });

        console.log(kleur.green('✅ Project created successfully!'));
        console.log();
        console.log(kleur.cyan('Next steps:'));
        console.log(`  cd ${result.projectName}`);

        if (result.installDeps) {
            console.log(kleur.yellow('📦 Installing dependencies...'));
            await installDependencies(projectPath);
            console.log(kleur.green('✅ Dependencies installed!'));
        } else {
            console.log('  npm install');
        }

        console.log('  npm run compile');
        console.log('  npm run deploy');
        console.log('  npm run send');
        console.log('  npm run verify');
        console.log();
        console.log(kleur.magenta('🚀 Happy proving!'));

    } catch (error) {
        console.error(kleur.red('❌ Error creating project:'), error.message);
        process.exit(1);
    }
}

async function copyBaseTemplate(templatePath, projectPath) {
    const sourceDir = path.join(__dirname, '../templates/base');

    const filesToCopy = [
        'contracts/',
        'circom_workflow.sh',
        'deploy.sh',
        'send_proof.sh',
        'receive_proof.sh',
        'verify_proof_directly.sh',
        'parse_proof_data.py',
        'decode_proof.sh',
        'send.sh',
        'generate_proof.sh',
        'README.md',
        'package.json',
        '.npmignore'
    ];

    for (const item of filesToCopy) {
        const sourcePath = path.join(sourceDir, item);
        const destPath = path.join(projectPath, item);

        if (await fs.pathExists(sourcePath)) {
            await fs.copy(sourcePath, destPath);
        }
    }
}

async function installDependencies(projectPath) {
    const { spawn } = require('child_process');

    return new Promise((resolve, reject) => {
        const npm = spawn('npm', ['install'], {
            cwd: projectPath,
            stdio: 'inherit'
        });

        npm.on('close', (code) => {
            if (code === 0) {
                resolve();
            } else {
                reject(new Error(`npm install failed with code ${code}`));
            }
        });
    });
}

main().catch(console.error); 