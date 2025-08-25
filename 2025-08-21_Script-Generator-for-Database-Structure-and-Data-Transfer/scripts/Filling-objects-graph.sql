    USP_GENSCRIPT_WRITE_LOG('OBJECTS GRAPH', 'PROCESSING', 'START', 'Filling objects graph', '-');
    BEGIN -- Filling objects graph
        v_Order := 1;
        -- finding objects at level zero (objects without dependencies)
        INSERT INTO SYS.GENSCRIPT_OBJECT_ORDERS 
            (OBJECT_OWNER, OBJECT_TYPE, OBJECT_NAME, OBJECT, OBJECT_ORDER, DEPENDENTS)
          SELECT t.OBJECT_OWNER,
                 t.OBJECT_TYPE,
                 t.OBJECT_NAME,
                 t.OBJECT,
                 1,
                 t.DEPENDENTS
            FROM (SELECT OD.OBJECT_OWNER,
                         OD.OBJECT_TYPE,
                         OD.OBJECT_NAME,
                         OD.OBJECT,
                         OD.DEPENDS_ON_OWNER,
                         OD.DEPENDS_ON_TYPE,
                         OD.DEPENDS_ON_NAME,
                         OD.PARENT_OBJECT,
                         OD.DEPENDENTS,
                         (SELECT COUNT(*)
                            FROM SYS.GENSCRIPT_OBJECT_DEPENDENCIES OD1
                            WHERE OD1.OBJECT=OD.OBJECT AND OD1.PARENT_OBJECT<>'.') AS COUNTs
                    FROM SYS.GENSCRIPT_OBJECT_DEPENDENCIES OD
                ) t
              WHERE t.COUNTs=0;

        DELETE FROM SYS.GENSCRIPT_OBJECT_DEPENDENCIES
            WHERE OBJECT IN (SELECT OO.OBJECT FROM SYS.GENSCRIPT_OBJECT_ORDERS OO);

        DELETE FROM SYS.GENSCRIPT_OBJECT_DEPENDENCIES
            WHERE PARENT_OBJECT='.';

        USP_GENSCRIPT_WRITE_LOG('OBJECTS GRAPH', 'PROCESSING', 'Level='||v_order, 'Graph level created', '-');

        v_done:=FALSE;
        LOOP
            v_Order := v_Order + 1;

            INSERT INTO SYS.GENSCRIPT_OBJECT_ORDERS 
                        (OBJECT_OWNER, OBJECT_TYPE, OBJECT_NAME, OBJECT, OBJECT_ORDER, DEPENDENTS)
                WITH cte AS
                ( -- The objects that were created in the hierarchy do not exist.
                  SELECT OD.OBJECT_OWNER,
                         OD.OBJECT_TYPE,
                         OD.OBJECT_NAME,
                         OD.OBJECT,
                         OD.DEPENDS_ON_OWNER,
                         OD.DEPENDS_ON_TYPE,
                         OD.DEPENDS_ON_NAME,
                         OD.PARENT_OBJECT,
                         OD.DEPENDENTS
                    FROM SYS.GENSCRIPT_OBJECT_DEPENDENCIES OD
                    WHERE OD.OBJECT NOT IN (SELECT OO.OBJECT
                                              FROM SYS.GENSCRIPT_OBJECT_ORDERS OO)
                )
                , cte2 AS 
                ( -- Finding the next-level objects whose prerequisites are already defined.
                  SELECT  c.OBJECT_OWNER,c.OBJECT_TYPE,c.OBJECT_NAME,c.OBJECT,c.PARENT_OBJECT,
                          OO.OBJECT AS DEPENDENT_OPBJECT,C.DEPENDENTS,
                          (SELECT COUNT(*)
                              FROM cte c1
                              LEFT OUTER JOIN SYS.GENSCRIPT_OBJECT_ORDERS OO1
                                ON OO1.OBJECT=C1.PARENT_OBJECT
                              WHERE c1.OBJECT=c.OBJECT
                                  AND OO1.OBJECT IS NULL) AS COUNT_DEPENDENTS
                    FROM cte c
                    LEFT OUTER JOIN SYS.GENSCRIPT_OBJECT_ORDERS OO
                      ON OO.OBJECT=C.PARENT_OBJECT
                )
                SELECT  DISTINCT 
                        C1.OBJECT_OWNER,
                        C1.OBJECT_TYPE,
                        C1.OBJECT_NAME,
                        C1.OBJECT,
                        v_Order,
                        DBMS_LOB.SUBSTR(C1.DEPENDENTS, 32767, 1)
                  FROM cte2 C1
                      WHERE C1.COUNT_DEPENDENTS=0;

            DELETE FROM SYS.GENSCRIPT_OBJECT_DEPENDENCIES
                WHERE OBJECT IN (SELECT OO.OBJECT FROM SYS.GENSCRIPT_OBJECT_ORDERS OO);
            
            SELECT COUNT(*)
                INTO v_Count
                FROM SYS.GENSCRIPT_OBJECT_DEPENDENCIES;

            IF v_Count=0 THEN 
                v_Done:=TRUE; 
            END IF;
            USP_GENSCRIPT_WRITE_LOG('OBJECTS GRAPH', 'PROCESSING', 'Level='||v_order, 'Graph level created', '-');
            EXIT WHEN v_done;
        END LOOP;

        BEGIN -- Applying priorities to the specified objects
            UPDATE SYS.GENSCRIPT_OBJECTS O SET 
                    O.OBJ_ORDER = (SELECT t.OBJ_ORDER
                                      FROM (SELECT o1.OBJ_PK_CODE,
                                                  ROW_NUMBER() OVER (ORDER BY oo.OBJECT_ORDER, o1.OBJ_NAME) AS OBJ_ORDER
                                              FROM SYS.GENSCRIPT_OBJECTS o1
                                                LEFT OUTER JOIN SYS.GENSCRIPT_OBJECT_ORDERS oo
                                                  ON oo.OBJECT_TYPE=o1.OBJ_TYPE AND oo.OBJECT_NAME=o1.OBJ_NAME) t
                                      WHERE t.OBJ_PK_CODE=o.OBJ_PK_CODE)
                WHERE EXISTS (SELECT 1
                                FROM SYS.GENSCRIPT_OBJECTS o1
                                  LEFT OUTER JOIN SYS.GENSCRIPT_OBJECT_ORDERS oo
                                    ON oo.OBJECT_TYPE=o1.OBJ_TYPE AND oo.OBJECT_NAME=o1.OBJ_NAME
                                WHERE o1.OBJ_PK_CODE=o.OBJ_PK_CODE
                                );
            UPDATE SYS.GENSCRIPT_OBJECTS O SET 
                    O.OBJ_ORDER = 1
                WHERE O.OBJ_NAME='NEWID';
        END;
    END;
    USP_GENSCRIPT_WRITE_LOG('OBJECTS GRAPH', 'PROCESSING', 'DONE', 'Filling objects graph', '-');
