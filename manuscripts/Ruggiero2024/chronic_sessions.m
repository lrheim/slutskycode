

function basepaths = chronic_sessions(queryStr)

if strcmp(queryStr, 'bac')

    basepaths{1} = ["lh96_220120_090157";...
        "lh96_220121_090213";...
        "lh96_220122_090154";...
        "lh96_220123_090009";...
        "lh96_220124_090127";...
        "lh96_220125_090041"];

    basepaths{2} = ["lh107_220518_091200";...
        "lh107_220519_091300";...
        "lh107_220520_093000";...
        "lh107_220521_091000";...
        "lh107_220522_093000";...
        "lh107_220523_102100";...
        "lh107_220524_091100"];

    basepaths{3} = ["lh122_221223_092656";...       % took prev day baseline 
        "lh122_221225_091518";...
        "lh122_221226_100133";...
        "lh122_221227_094532";...
        "lh122_221228_102653";...
        "lh122_221229_090102"];

end

end