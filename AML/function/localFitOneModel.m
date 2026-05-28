%% ========================================================================
% 局部函数：拟合单个SARIMA模型
% ========================================================================
function [aic, bic, logL, numParam, isConverged, errMsg, EstMdl, info] = ...
    localFitOneModel(combo, y, constantValue, displayMode, optimOptions, numObsIC)

    p = combo(1);
    d = combo(2);
    q = combo(3);
    P = combo(4);
    D = combo(5);
    Q = combo(6);
    s = combo(7);

    aic = inf;
    bic = inf;
    logL = nan;
    numParam = nan;
    isConverged = false;
    errMsg = '';
    EstMdl = [];
    info = [];

    try
        Mdl = localCreateSarimaModel(p, d, q, P, D, Q, s, constantValue);

        if isempty(optimOptions)
            [EstMdl, EstParamCov, logL, info] = estimate( ...
                Mdl, y, ...
                'Display', displayMode);
        else
            [EstMdl, EstParamCov, logL, info] = estimate( ...
                Mdl, y, ...
                'Display', displayMode, ...
                'Options', optimOptions);
        end

        if ~isempty(EstParamCov)
            numParam = size(EstParamCov, 1);
        else
            numParam = localFallbackNumParam(p, q, P, Q, constantValue);
        end

        [aic, bic] = aicbic(logL, numParam, numObsIC);

        isConverged = true;
        if isstruct(info)
            if isfield(info, 'ExitFlag')
                isConverged = info.ExitFlag > 0;
            elseif isfield(info, 'exitflag')
                isConverged = info.exitflag > 0;
            end
        end

    catch ME
        errMsg = ME.message;
    end
end

