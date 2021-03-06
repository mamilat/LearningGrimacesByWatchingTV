function [opts, bestNet] = expDefaults(mode, model, gpus, bs, bn, lr, local, opts)
% Returns default options used in experiments

% set path to data root
DATA_ROOT = '~/data' ;

% generate the experiment name
if ~strcmp(mode, 'test-deployed')
    experimentName = buildExpName(model, bn, lr);
else
    experimentName = model;
end

% set shared options
opts.expType = 'benchmarks';
opts.pretrainedNet = model;
opts.modifyForTask = @modifyForFER;
experimentRoot = fullfile(DATA_ROOT, 'emotions', 'fer');
opts.modelDir = fullfile(DATA_ROOT, 'models', 'matconvnet');
opts.dataDir = fullfile(experimentRoot, 'data');
rootExpPath = fullfile(experimentRoot, 'experiments', opts.expType, ...
    model, experimentName);

% --------------------------------------------------------------------
%                                                   Training the model
% --------------------------------------------------------------------

if strcmp(mode, 'train')
    opts.train.gpus = gpus;
    opts.train.LRflip = true;
    opts.train.continue = true;
    opts.train.numEpochs = 60;
    opts.train.batchSize = bs;

    % define possible learning schedules
    keys = {'e2', 'e3', 'e4', 'log24'};
    values = {0.01, 0.001, 0.001, logspace(-2, -4, opts.train.numEpochs)};
    learningSchedules = containers.Map(keys, values);
    
    opts.train.learningRate = learningSchedules(lr);
    opts.fineTuningRate = 0.1;
    opts.expDir = fullfile(rootExpPath, 'train');
    opts.imdbPath = fullfile(opts.dataDir, 'imdbs', 'imdb.mat');
    opts.train.expDir = opts.expDir;
    opts.local = local;
    opts.useBnorm = bn;
    opts % display options
    trainCNN(opts);
end

% --------------------------------------------------------------------
%                                                    Testing the model
% --------------------------------------------------------------------

if strcmp(mode, 'test')
    opts.test.gpus = gpus;
    opts.test.numEpochs = 1;
    opts.test.testMode = true;
    opts.test.batchSize = bs;

    % Load the network from the best epoch of training
    bestEpoch = findBestCheckpoint(fullfile(rootExpPath, 'train'));
    data = load(fullfile(rootExpPath, 'train', ...
        strcat('net-epoch-', num2str(bestEpoch), '.mat')));
    bestNet = data.net;

    opts.test.bestEpoch = bestEpoch;
    opts.expDir = fullfile(rootExpPath, 'test');
    opts.imdbPath = fullfile(opts.dataDir, 'imdbs', 'imdb_test.mat');
    opts.test.expDir = opts.expDir;
    opts.local = local;
    testCNN(bestNet, opts);
end

if strcmp(mode, 'test-deployed')
    opts.test.gpus = gpus ;
    opts.test.numEpochs = 1 ;
    opts.test.testMode = true ;
    opts.test.batchSize = bs ;

    % Load the deployed network
    net = initPretrainedNet(opts)
    opts.expDir = fullfile(rootExpPath, 'test') ;
    opts.imdbPath = fullfile(opts.dataDir, 'imdbs', 'imdb_test.mat') ;
    opts.test.expDir = opts.expDir ;
    opts.test.bestEpoch = 1;
    opts.local = false ;
    testCNN(net, opts) ;
end

% --------------------------------------------------------------------
function experimentName = buildExpName(model, bn, lr)
% --------------------------------------------------------------------
experimentName = model;
if bn
    experimentName = sprintf('%s_bn', experimentName);
end
experimentName = sprintf('%s_%s', experimentName, lr);
