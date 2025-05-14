classdef VariableSaveManager < handle
    % VariableSaveManager Class for efficient management of persistent storage and loading of variables
    % Core features:
    %   - Automatic hash verification: Only perform actual storage when variable content changes, improving efficiency of repeated saves
    %   - Incremental storage management: Automatically clean up old variables no longer needing storage (moved to recycle bin)
    %   - Multi-version compatibility: Support loading variable data saved in different historical versions
    %   - Graphics object filtering: Automatically skip graphics objects that cannot be saved with save()
    % Usage:
    %   - Create object: obj = VariableSaveManager() or obj = VariableSaveManager('path') (default path is 'matlab_data')
    %       Variables will be saved in the 'path' subdirectory of the MATLAB working directory. Each variable is saved as a .mat file, 
    %       with an additional datainfo__.mat file storing hash values of all variables.
    %   - Save variables: obj.save_var(struct(varname1,var1,...)), supports multiple variables.
    %   - Load variables: obj.load_vars(), automatically loads all saved variables to the workspace. Can also be opened directly in MATLAB by selecting all saved variables in Windows Explorer.
    %   - View status: obj.varnames lists the names of saved variables

    %% Properties
    properties
        storePath = 'matlab_data';       % Root directory for variable storage (relative to current working directory)
        infoFileName = 'datainfo__.mat'; % Metadata file name (stores variable names and hash values)
        varnames = {};         % List of saved variable names (cell array)
        hash = {};             % List of hash values for corresponding variables (one-to-one with varnames)
    end

    %% Public Methods
    methods
        function obj = VariableSaveManager(varargin)
            % VariableSaveManager constructor
            % Input arguments:
            %   Optional argument 1: Storage path (string), specifies the root directory for variable storage (default 'matlab_data')
            % Exceptions:
            %   Throws error if path contains invalid characters

            if nargin == 1
                obj.storePath = varargin{1};
                
                % Validate path validity (prohibit system reserved characters)
                invalidChars = '[/\*:?"<>|]';
                if ~isempty(regexp(obj.storePath, invalidChars, 'once'))
                    error('%s: Invalid storage path "%s", path cannot contain the following characters: %s', ...
                          mfilename, obj.storePath, invalidChars);
                end
            end
            
            % Enable MATLAB recycle bin (prevent accidental file deletion)
            recycle('on');
        end

        function load_info(obj)
            % Load storage metadata (variable names and hash values) from file
            % Output:
            %   Directly updates the object's varnames and hash properties
            % Exceptions:
            %   Throws error if metadata file is corrupted

            infoPath = fullfile(obj.storePath, obj.infoFileName);
            if exist(infoPath, 'file')
                try
                    % Only load specified fields to prevent loading malicious data when file is tampered
                    info = load(infoPath, 'varnames', 'hash');
                    obj.varnames = info.varnames;
                    obj.hash = info.hash;
                catch ME
                    error('%s: Failed to load metadata file. Error message: %s (file may be corrupted)', ...
                          mfilename, ME.message);
                end
            else
                obj.varnames = {};
                obj.hash = {};
            end
        end

        function save_info(obj)
            % Save current metadata (variable names and hash values) to file
            % Exceptions:
            %   Throws error if metadata save fails
            
            workingPath = fullfile(pwd, obj.storePath);
            infoPath = fullfile(workingPath, obj.infoFileName);
            varnames=obj.varnames; %#ok<PROP>
            hash=obj.hash; %#ok<PROP>
            try
                save(infoPath, 'varnames', 'hash');
            catch ME
                error('%s: Metadata save failed. Error message: %s (check directory permissions)', mfilename, ME.message);
            end
        end

        function save_var(obj, new_vars)
            % Save specified variable set to storage directory (core method)
            % Input arguments:
            %   new_vars: Set of variables to save (non-empty structure, field names are variable names, field values are variable contents)
            % Exceptions:
            %   Throws error if new_vars is not a structure
            
            % Input argument validation
            validateattributes(new_vars, {'struct'}, {}, mfilename, 'new_vars');

            obj.load_info();
            newVarNames = fieldnames(new_vars);
            workingPath = fullfile(pwd, obj.storePath);
            % Ensure workingPath exists
            if ~exist(workingPath, 'dir')
                mkdir(workingPath);
            end

            %% Step 1: Clean up old variables no longer needing storage (reverse traversal to prevent index confusion)
            for i = length(obj.varnames):-1:1
                oldVarName = obj.varnames{i};
                if ~ismember(oldVarName, newVarNames)
                    % Remove record from metadata
                    obj.varnames(i) = [];
                    obj.hash(i) = [];
                    
                    % Delete physical file (use recycle for recoverability)
                    varPath = fullfile(workingPath, [oldVarName, '.mat']);
                    if exist(varPath, 'file')
                        delete(varPath);  % Recycle enabled, actually moves to recycle bin
                    else
                        warning('%s: Attempted to delete non-existent variable file - %s', mfilename, varPath);
                    end
                end
            end

            %% Step 2: Process new/updated variables (forward traversal of new variable list)
            for i = 1:length(newVarNames)
                newVarName = newVarNames{i};
                varValue = new_vars.(newVarName);
                
                % Skip graphics objects (cannot be saved with save())
                if isgraphics(varValue)
                    warning('%s: Skipping unsavable graphics object variable - %s', mfilename, newVarName);
                    continue;
                end

                %% Calculate hash value (key deduplication logic)
                try
                    newVarHash = obj.get_hash(varValue);
                catch ME
                    error('%s: Failed to calculate hash for variable %s. Error message: %s', mfilename, newVarName, ME.message);
                end

                %% Storage logic
                varPath = fullfile(workingPath, [newVarName, '.mat']);
                var = struct(newVarName, varValue);  % Package variable value as structure
                if ~ismember(newVarName, obj.varnames)
                    % New variable: Directly save structure field
                    save(varPath, '-struct', 'var', '-v7.3');
                    obj.varnames{end+1} = newVarName;
                    obj.hash{end+1} = newVarHash;
                else
                    % Existing variable: Verify hash value
                    hashIdx = find(strcmp(obj.varnames, newVarName), 1);
                    if ~isequal(newVarHash, obj.hash{hashIdx})
                        % Content changed: Update file and hash value
                        save(varPath, '-struct', 'var', '-v7.3');
                        obj.hash{hashIdx} = newVarHash;
                    end
                end
            end

            %% Save latest metadata (ensure state consistency)
            obj.save_info();
        end

        function hash = get_hash(~, var)
            % Calculate hash value of variable (for content change detection)
            % Input:
            %   var: Any type of MATLAB variable
            % Output:
            %   hash: Hash value of variable content (generated by DataHash_v2 function)
            % References
            %   A fast way to convert MATLAB variable to byteStream:
            %   - https://undocumentedmatlab.com/articles/serializing-deserializing-matlab-data
            %   a fast hash:
            %   - https://github.com/Cyan4973/xxHash
            hash = DataHash_v2_core(getByteStreamFromArray(var));
        end

        function load_vars(obj)
            % Load all saved variables to MATLAB workspace
            % Exceptions:
            %   Throws warning if storage directory does not exist
            
            workingPath = fullfile(pwd, obj.storePath);
            if ~exist(workingPath, 'dir')
                warning('%s: Storage directory does not exist - %s', mfilename, workingPath);
                return;
            end

            obj.load_info();
            for i = 1:length(obj.varnames)
                varName = obj.varnames{i};
                varPath = fullfile(workingPath, [varName, '.mat']);
                
                if exist(varPath, 'file')
                    try
                        % Load only target variable when loading (prevent loading malicious data when file is tampered)
                        loadedData = load(varPath, varName);
                        varValue = loadedData.(varName);
                        
                        % Write to workspace (with variable name normalization)
                        obj.assignVariableToWorkspace(varName, varValue);
                    catch ME
                        warning('%s: Failed to load variable %s. Error message: %s', mfilename, varName, ME.message);
                    end
                else
                    warning('%s: Missing variable file - %s', mfilename, varPath);
                end
            end
        end
    end

    %% Private Methods (Encapsulate internal implementation details)
    methods (Access = private)
        function assignVariableToWorkspace(~, varName, varValue)
            % Private method: Write variable to MATLAB base workspace (with name normalization)
            % Input:
            %   varName: Original variable name (may contain invalid characters)
            %   varValue: Variable value
            % Specification:
            %   MATLAB variable name requirements: Starts with letter, contains only letters, numbers, and underscores, length ≤63 characters

            % 1. Replace invalid characters with underscores (non-alphanumeric characters)
            invalidMask = ~isstrprop(varName, 'alphanum') | (double(varName) >= 255);
            safeVarName = varName;
            safeVarName(invalidMask) = '_';

            % 2. Ensure starts with letter (add prefix if not)
            if ~isempty(safeVarName) && ~isletter(safeVarName(1))
                safeVarName = ['Var_', safeVarName];
            end

            % 3. Limit maximum length (MATLAB variable name max 63 characters)
            if length(safeVarName) > 63
                safeVarName = safeVarName(1:63);
            end

            % 4. Write to base workspace (avoid overwriting critical variables)
            if isempty(safeVarName)
                safeVarName = 'UnnamedVar';  % Prevent empty name
            end
            assignin('base', safeVarName, varValue);
        end
    end
end
