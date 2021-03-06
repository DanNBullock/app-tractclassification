function [] = main()

switch getenv('ENV')
    case 'IUHPC'
        disp('loading paths for IUHPC')
        addpath(genpath('/N/u/brlife/git/encode'))
        addpath(genpath('/N/u/brlife/git/vistasoft'))
        addpath(genpath('/N/u/brlife/git/jsonlab'))
        addpath(genpath('/N/u/brlife/git/afq'))
    case 'VM'
        disp('loading paths for Jetstream VM')
        addpath(genpath('/usr/local/encode'))
        addpath(genpath('/usr/local/vistasoft'))
        addpath(genpath('/usr/local/jsonlab'))
        addpath(genpath('/usr/local/afq-master'))
end

% load my own config.json
config = loadjson('config.json');

% Load an FE strcuture created by the sca-service-life
load(config.fe);

% Extract the fascicles
fg = feGet(fe,'fibers acpc');

if strcmp(config.remove_zero_weighted_fibers, 'before')
        % Extract the fascicle weights from the fe structure
        % Dependency "encode".
        w = feGet(fe,'fiber weights');
        
        % Eliminate the fascicles with non-zero entries
        % Dependency "vistasoft"
        fg = fgExtract(fg, w > 0, 'keep');
end

% Classify the major tracts from all the fascicles
% Dependency "AFQ" use this repository: https://github.com/francopestilli/afq
[fg_classified,~,classification]= AFQ_SegmentFiberGroups(fullfile(config.dtiinit, 'dti/dt6.mat'), fg, [], [], config.useinterhemisphericsplit);
%if removing 0 weighted fibers after AFQ:

if strcmp(config.remove_zero_weighted_fibers, 'after')
        invalidIndicies=find(fe.life.fit.weights==0);
        classification.index(invalidIndicies)=0;    
        for itracts=1:length(classification.names)
            fg_classified(itracts).fibers = fg.fibers(classification.index==itracts);
        end
end

tracts = fg2Array(fg_classified);
clear fg

mkdir('tracts');

% Make colors for the tracts
cm = parula(length(tracts));
for it = 1:length(tracts)
   tract.name   = tracts(it).name;
   tract.color  = cm(it,:);
   tract.coords = tracts(it).fibers;
   all_tracts(it).name = tracts(it).name;
   all_tracts(it).color = cm(it,:);
   savejson('', tract, fullfile('tracts',sprintf('%i.json',it)));
   all_tracts(it).filename = sprintf('%i.json',it);
   clear tract
end

savejson('', all_tracts, fullfile('tracts/tracts.json'));

% Save the results to disk
save('output.mat','fg_classified','classification');

% saving text file with number of fibers per tracts
tract_info = cell(length(fg_classified), 2);

possible_error = 0;
for i = 1:length(fg_classified)
    tract_info{i,1} = fg_classified(i).name;
    tract_info{i,2} = length(fg_classified(i).fibers);
    if length(fg_classified(i).fibers) < 20
        possible_error=1;
    end
end

if possible_error==1
    results.quality_check = 'ERROR: Some tracts have less than 20 streamlines. Check quality of data!'
else
    results.quality_check = 'Data should be fine, but please view to double check'
end
savejson('', results, 'product.json');

T = cell2table(tract_info);
T.Properties.VariableNames = {'Tracts', 'FiberCount'};

writetable(T,'output_fibercounts.txt')

